// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAggregatorV3} from "src/interfaces/IAggregatorV3.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {USDOracleRule} from "src/modules/rules/USDOracleRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";
import {MockAggregatorV3} from "test/mocks/MockAggregatorV3.sol";

contract USDOracleRuleTest is NamespaceSetUp {
    USDOracleRule internal rule;
    MockAggregatorV3 internal oracle;

    function setUp() public override {
        super.setUp();
        rule = USDOracleRule(_deployModule(address(new USDOracleRule())));
        oracle = new MockAggregatorV3(8, 2_000e8);
    }

    function test_evaluateMint_convertsUsdPriceToTokenAmount() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, 100e18, 25e18, 18, 1 days, NamespaceTypes.PriceOp.SET_BASE);

        NamespaceTypes.RuleOutput memory output = rule.evaluateMint(_mintCtx(activationId), "");

        assertEq(uint256(output.decision), uint256(NamespaceTypes.Decision.PASS));
        assertEq(uint256(output.priceOp), uint256(NamespaceTypes.PriceOp.SET_BASE));
        assertEq(output.token, address(token));
        assertEq(output.amount, 0.05 ether);
    }

    function test_evaluateRenew_convertsUsdPriceToTokenAmount() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, 100e18, 25e18, 18, 1 days, NamespaceTypes.PriceOp.SET_BASE);

        NamespaceTypes.RuleOutput memory output = rule.evaluateRenew(_renewCtx(activationId), "");

        assertEq(output.amount, 0.0125 ether);
    }

    function test_evaluateMint_roundsUpTokenAmount() public {
        bytes32 activationId = keccak256("activation");
        oracle.setRoundData(3e8, block.timestamp);
        _configure(activationId, 1e18, 0, 6, 1 days, NamespaceTypes.PriceOp.SET_BASE);

        NamespaceTypes.RuleOutput memory output = rule.evaluateMint(_mintCtx(activationId), "");

        assertEq(output.amount, 333_334);
    }

    function test_configure_revertsForInvalidOracleParamsAndPriceOp() public {
        bytes32 activationId = keccak256("activation");

        vm.expectRevert(abi.encodeWithSelector(USDOracleRule.ZeroOracle.selector, activationId));
        vm.prank(address(controller));
        rule.configure(
            activationId,
            abi.encode(
                USDOracleRule.Params({
                    token: address(token),
                    oracle: IAggregatorV3(address(0)),
                    tokenDecimals: 18,
                    maxStaleness: 1 days,
                    mintUsdPrice: 100e18,
                    renewUsdPrice: 25e18,
                    priceOp: NamespaceTypes.PriceOp.SET_BASE
                })
            )
        );

        vm.expectRevert(abi.encodeWithSelector(USDOracleRule.InvalidMaxStaleness.selector));
        vm.prank(address(controller));
        rule.configure(
            activationId,
            abi.encode(
                USDOracleRule.Params({
                    token: address(token),
                    oracle: IAggregatorV3(address(oracle)),
                    tokenDecimals: 18,
                    maxStaleness: 0,
                    mintUsdPrice: 100e18,
                    renewUsdPrice: 25e18,
                    priceOp: NamespaceTypes.PriceOp.SET_BASE
                })
            )
        );

        vm.expectRevert(abi.encodeWithSelector(USDOracleRule.InvalidTokenDecimals.selector, uint8(19)));
        vm.prank(address(controller));
        rule.configure(
            activationId,
            abi.encode(
                USDOracleRule.Params({
                    token: address(token),
                    oracle: IAggregatorV3(address(oracle)),
                    tokenDecimals: 19,
                    maxStaleness: 1 days,
                    mintUsdPrice: 100e18,
                    renewUsdPrice: 25e18,
                    priceOp: NamespaceTypes.PriceOp.SET_BASE
                })
            )
        );

        MockAggregatorV3 highDecimalOracle = new MockAggregatorV3(19, 2_000e8);
        vm.expectRevert(abi.encodeWithSelector(USDOracleRule.InvalidOracleDecimals.selector, uint8(19)));
        vm.prank(address(controller));
        rule.configure(
            activationId,
            abi.encode(
                USDOracleRule.Params({
                    token: address(token),
                    oracle: IAggregatorV3(address(highDecimalOracle)),
                    tokenDecimals: 18,
                    maxStaleness: 1 days,
                    mintUsdPrice: 100e18,
                    renewUsdPrice: 25e18,
                    priceOp: NamespaceTypes.PriceOp.SET_BASE
                })
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(USDOracleRule.InvalidUSDOraclePriceOp.selector, NamespaceTypes.PriceOp.DISCOUNT_BPS)
        );
        vm.prank(address(controller));
        rule.configure(
            activationId,
            abi.encode(
                USDOracleRule.Params({
                    token: address(token),
                    oracle: IAggregatorV3(address(oracle)),
                    tokenDecimals: 18,
                    maxStaleness: 1 days,
                    mintUsdPrice: 100e18,
                    renewUsdPrice: 25e18,
                    priceOp: NamespaceTypes.PriceOp.DISCOUNT_BPS
                })
            )
        );
    }

    function test_evaluateMint_revertsOnStaleOraclePrice() public {
        vm.warp(10 days);
        bytes32 activationId = keccak256("activation");
        _configure(activationId, 100e18, 25e18, 18, 1 hours, NamespaceTypes.PriceOp.SET_BASE);
        oracle.setRoundData(2_000e8, block.timestamp - 2 hours);

        vm.expectRevert(
            abi.encodeWithSelector(
                USDOracleRule.StaleOraclePrice.selector, block.timestamp - 2 hours, 1 hours, block.timestamp
            )
        );
        rule.evaluateMint(_mintCtx(activationId), "");
    }

    function test_evaluateMint_revertsOnInvalidOraclePrice() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, 100e18, 25e18, 18, 1 days, NamespaceTypes.PriceOp.SET_BASE);
        oracle.setRoundData(0, block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(USDOracleRule.InvalidOraclePrice.selector, int256(0)));
        rule.evaluateMint(_mintCtx(activationId), "");
    }

    function test_evaluateMint_revertsOnInvalidOracleRound() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, 100e18, 25e18, 18, 1 days, NamespaceTypes.PriceOp.SET_BASE);
        oracle.setRoundData(2_000e8, block.timestamp);
        oracle.setAnsweredInRound(1);

        vm.expectRevert(
            abi.encodeWithSelector(USDOracleRule.InvalidOracleRound.selector, uint80(2), block.timestamp, uint80(1))
        );
        rule.evaluateMint(_mintCtx(activationId), "");
    }

    function _configure(
        bytes32 activationId,
        uint128 mintUsdPrice,
        uint128 renewUsdPrice,
        uint8 tokenDecimals,
        uint64 maxStaleness,
        NamespaceTypes.PriceOp priceOp
    ) private {
        vm.prank(address(controller));
        rule.configure(
            activationId,
            abi.encode(
                USDOracleRule.Params({
                    token: address(token),
                    oracle: IAggregatorV3(address(oracle)),
                    tokenDecimals: tokenDecimals,
                    maxStaleness: maxStaleness,
                    mintUsdPrice: mintUsdPrice,
                    renewUsdPrice: renewUsdPrice,
                    priceOp: priceOp
                })
            )
        );
    }

    function _mintCtx(bytes32 activationId) private view returns (NamespaceTypes.MintContext memory ctx) {
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;
        ctx.payer = accounts.buyer.addr;
        ctx.label = "usd";
        ctx.labelHash = keccak256("usd");
        ctx.duration = 365 days;
    }

    function _renewCtx(bytes32 activationId) private view returns (NamespaceTypes.RenewContext memory ctx) {
        ctx.activationId = activationId;
        ctx.payer = accounts.buyer.addr;
        ctx.label = "usd";
        ctx.labelHash = keccak256("usd");
        ctx.duration = 30 days;
    }
}
