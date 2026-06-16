// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {IAggregatorV3} from "src/interfaces/IAggregatorV3.sol";
import {USDOraclePricing} from "src/modules/pricing/USDOraclePricing.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";
import {MockAggregatorV3} from "test/mocks/MockAggregatorV3.sol";

contract USDOraclePricingTest is NamespaceSetUp {
    USDOraclePricing internal pricing;
    MockAggregatorV3 internal oracle;

    function setUp() public override {
        super.setUp();
        pricing = USDOraclePricing(_deployModule(address(new USDOraclePricing())));
        oracle = new MockAggregatorV3(8, 2_000e8);
    }

    function test_quoteMint_convertsUsdPriceToTokenAmount() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, 100e18, 25e18, 18, 1 days);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        NamespaceTypes.Price memory quoted = pricing.quoteMint(ctx, NamespaceTypes.Price(address(0), 0), "");

        assertEq(quoted.token, address(token));
        assertEq(quoted.amount, 0.05 ether);
    }

    function test_quoteRenew_convertsUsdPriceToTokenAmount() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, 100e18, 25e18, 18, 1 days);

        NamespaceTypes.RenewContext memory ctx;
        ctx.activationId = activationId;

        NamespaceTypes.Price memory quoted = pricing.quoteRenew(ctx, NamespaceTypes.Price(address(0), 0), "");

        assertEq(quoted.token, address(token));
        assertEq(quoted.amount, 0.0125 ether);
    }

    function test_quoteMint_roundsUpTokenAmount() public {
        bytes32 activationId = keccak256("activation");
        oracle.setRoundData(3e8, block.timestamp);
        _configure(activationId, 1e18, 0, 6, 1 days);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        NamespaceTypes.Price memory quoted = pricing.quoteMint(ctx, NamespaceTypes.Price(address(0), 0), "");

        assertEq(quoted.amount, 333_334);
    }

    function test_quoteMint_addsToCurrentPrice() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, 100e18, 25e18, 18, 1 days);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        NamespaceTypes.Price memory quoted = pricing.quoteMint(ctx, NamespaceTypes.Price(address(token), 1 ether), "");

        assertEq(quoted.amount, 1.05 ether);
    }

    function test_quoteMint_revertsOnPaymentTokenMismatch() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, 100e18, 25e18, 18, 1 days);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        vm.expectRevert(
            abi.encodeWithSelector(USDOraclePricing.PaymentTokenMismatch.selector, address(0xBEEF), address(token))
        );
        pricing.quoteMint(ctx, NamespaceTypes.Price(address(0xBEEF), 1 ether), "");
    }

    function test_quoteMint_revertsOnStaleOraclePrice() public {
        vm.warp(10 days);
        bytes32 activationId = keccak256("activation");
        _configure(activationId, 100e18, 25e18, 18, 1 hours);
        oracle.setRoundData(2_000e8, block.timestamp - 2 hours);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        vm.expectRevert(
            abi.encodeWithSelector(
                USDOraclePricing.StaleOraclePrice.selector, block.timestamp - 2 hours, 1 hours, block.timestamp
            )
        );
        pricing.quoteMint(ctx, NamespaceTypes.Price(address(0), 0), "");
    }

    function test_quoteMint_revertsOnInvalidOraclePrice() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, 100e18, 25e18, 18, 1 days);
        oracle.setRoundData(0, block.timestamp);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        vm.expectRevert(abi.encodeWithSelector(USDOraclePricing.InvalidOraclePrice.selector, int256(0)));
        pricing.quoteMint(ctx, NamespaceTypes.Price(address(0), 0), "");
    }

    function test_quoteMint_revertsOnInvalidOracleRound() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, 100e18, 25e18, 18, 1 days);
        oracle.setRoundData(2_000e8, block.timestamp);
        oracle.setAnsweredInRound(1);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        vm.expectRevert(
            abi.encodeWithSelector(USDOraclePricing.InvalidOracleRound.selector, uint80(2), block.timestamp, uint80(1))
        );
        pricing.quoteMint(ctx, NamespaceTypes.Price(address(0), 0), "");
    }

    function _configure(
        bytes32 activationId,
        uint128 mintUsdPrice,
        uint128 renewUsdPrice,
        uint8 tokenDecimals,
        uint64 maxStaleness
    ) private {
        vm.prank(address(controller));
        pricing.configure(
            activationId,
            abi.encode(
                USDOraclePricing.Params({
                    token: address(token),
                    oracle: IAggregatorV3(address(oracle)),
                    tokenDecimals: tokenDecimals,
                    maxStaleness: maxStaleness,
                    mintUsdPrice: mintUsdPrice,
                    renewUsdPrice: renewUsdPrice
                })
            )
        );
    }
}
