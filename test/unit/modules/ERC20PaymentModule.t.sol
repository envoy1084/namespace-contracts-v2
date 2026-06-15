// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract ERC20PaymentModuleTest is NamespaceSetUp {
    function test_collectMint_transfersPaymentToRecipient() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        erc20Payment.configure(
            activationId, abi.encode(ERC20PaymentModule.Params({token: token, recipient: accounts.treasury.addr}))
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.payer = accounts.buyer.addr;

        vm.prank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100);

        vm.prank(address(controller));
        erc20Payment.collectMint(ctx, NamespaceTypes.Price({token: address(token), amount: 100}), "");

        assertEq(token.balanceOf(accounts.treasury.addr), 100);
    }

    function test_collectMint_revertsFromNonController() public {
        NamespaceTypes.MintContext memory ctx;

        vm.expectRevert();
        erc20Payment.collectMint(ctx, NamespaceTypes.Price({token: address(token), amount: 100}), "");
    }
}
