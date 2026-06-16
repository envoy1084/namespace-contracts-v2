// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {LengthBasedPricing} from "src/modules/pricing/LengthBasedPricing.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract LengthBasedPricingTest is NamespaceSetUp {
    LengthBasedPricing internal pricing;

    function setUp() public override {
        super.setUp();
        pricing = LengthBasedPricing(_deployModule(address(new LengthBasedPricing())));
    }

    function test_quoteMint_usesExactLengthBucket() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.label = "pay";
        ctx.duration = 10;

        NamespaceTypes.Price memory quoted = pricing.quoteMint(ctx, NamespaceTypes.Price(address(0), 0), "");

        assertEq(quoted.token, address(token));
        assertEq(quoted.amount, 30);
    }

    function test_quoteMint_usesLastBucketForLongLabels() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.label = "longlabel";
        ctx.duration = 10;

        NamespaceTypes.Price memory quoted = pricing.quoteMint(ctx, NamespaceTypes.Price(address(0), 0), "");

        assertEq(quoted.amount, 50);
    }

    function _configure(bytes32 activationId) private {
        uint128[] memory mintRates = new uint128[](5);
        mintRates[0] = 10;
        mintRates[1] = 5;
        mintRates[2] = 3;
        mintRates[3] = 2;
        mintRates[4] = 5;

        uint128[] memory renewRates = new uint128[](1);
        renewRates[0] = 1;

        vm.prank(address(controller));
        pricing.configure(
            activationId,
            abi.encode(
                LengthBasedPricing.Params({
                    token: address(token),
                    mintPricePerSecondByLength: mintRates,
                    renewPricePerSecondByLength: renewRates
                })
            )
        );
    }
}
