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
            abi.encode(FixedPricePricing.Params({token: address(token), mintAmount: 100, renewAmount: 50}))
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        NamespaceTypes.Price memory quoted =
            fixedPricePricing.quoteMint(ctx, NamespaceTypes.Price({token: address(token), amount: 25}), "");

        assertEq(quoted.token, address(token));
        assertEq(quoted.amount, 125);
    }
}
