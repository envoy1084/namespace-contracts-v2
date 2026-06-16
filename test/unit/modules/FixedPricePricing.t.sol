// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {FixedPricePricing} from "src/modules/pricing/FixedPricePricing.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract FixedPricePricingTest is NamespaceSetUp {
    function test_quoteMint_addsFixedAmountToCurrentPrice() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        fixedPricePricing.configure(
            activationId,
            abi.encode(
                FixedPricePricing.Params({
                    token: address(token),
                    defaultMintAmount: 100,
                    defaultRenewAmount: 50,
                    lengthPrices: new FixedPricePricing.LengthPrice[](0)
                })
            )
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.label = "pay";

        NamespaceTypes.Price memory quoted =
            fixedPricePricing.quoteMint(ctx, NamespaceTypes.Price({token: address(token), amount: 25}), "");

        assertEq(quoted.token, address(token));
        assertEq(quoted.amount, 125);
    }

    function test_quoteMint_usesSparseExactLengthPrice() public {
        bytes32 activationId = keccak256("activation");
        FixedPricePricing.LengthPrice[] memory lengthPrices = new FixedPricePricing.LengthPrice[](2);
        lengthPrices[0] = FixedPricePricing.LengthPrice({length: 4, mintAmount: 400, renewAmount: 40});
        lengthPrices[1] = FixedPricePricing.LengthPrice({length: 8, mintAmount: 800, renewAmount: 80});

        vm.prank(address(controller));
        fixedPricePricing.configure(
            activationId,
            abi.encode(
                FixedPricePricing.Params({
                    token: address(token), defaultMintAmount: 100, defaultRenewAmount: 50, lengthPrices: lengthPrices
                })
            )
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.label = "four";

        NamespaceTypes.Price memory quoted = fixedPricePricing.quoteMint(ctx, NamespaceTypes.Price(address(0), 0), "");

        assertEq(quoted.amount, 400);
    }

    function test_quoteMint_usesDefaultWhenNoLengthPriceMatches() public {
        bytes32 activationId = keccak256("activation");
        FixedPricePricing.LengthPrice[] memory lengthPrices = new FixedPricePricing.LengthPrice[](1);
        lengthPrices[0] = FixedPricePricing.LengthPrice({length: 4, mintAmount: 400, renewAmount: 40});

        vm.prank(address(controller));
        fixedPricePricing.configure(
            activationId,
            abi.encode(
                FixedPricePricing.Params({
                    token: address(token), defaultMintAmount: 100, defaultRenewAmount: 50, lengthPrices: lengthPrices
                })
            )
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.label = "five5";

        NamespaceTypes.Price memory quoted = fixedPricePricing.quoteMint(ctx, NamespaceTypes.Price(address(0), 0), "");

        assertEq(quoted.amount, 100);
    }

    function test_configure_revertsOnDuplicateLengthPrice() public {
        bytes32 activationId = keccak256("activation");
        FixedPricePricing.LengthPrice[] memory lengthPrices = new FixedPricePricing.LengthPrice[](2);
        lengthPrices[0] = FixedPricePricing.LengthPrice({length: 4, mintAmount: 400, renewAmount: 40});
        lengthPrices[1] = FixedPricePricing.LengthPrice({length: 4, mintAmount: 500, renewAmount: 50});

        vm.expectRevert(abi.encodeWithSelector(FixedPricePricing.DuplicateLengthPrice.selector, activationId, 4));
        vm.prank(address(controller));
        fixedPricePricing.configure(
            activationId,
            abi.encode(
                FixedPricePricing.Params({
                    token: address(token), defaultMintAmount: 100, defaultRenewAmount: 50, lengthPrices: lengthPrices
                })
            )
        );
    }
}
