// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LibClone} from "solady/utils/LibClone.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";
import {FeeOnTransferERC20} from "test/mocks/FeeOnTransferERC20.sol";

contract ERC20PaymentModuleTest is NamespaceSetUp {
    function test_initialize_revertsForZeroController() public {
        ERC20PaymentModule implementation = new ERC20PaymentModule();
        ERC20PaymentModule proxy = ERC20PaymentModule(payable(LibClone.deployERC1967(address(implementation))));

        vm.expectRevert(abi.encodeWithSelector(NamespaceModule.ZeroController.selector));
        proxy.initialize(address(0), accounts.owner.addr);
    }

    function test_configure_revertsForInvalidRecipient() public {
        bytes32 activationId = keccak256("activation");

        vm.expectRevert(abi.encodeWithSelector(ERC20PaymentModule.InvalidPaymentRecipient.selector));
        vm.prank(address(controller));
        erc20Payment.configure(
            activationId, abi.encode(ERC20PaymentModule.Params({token: token, recipient: address(0)}))
        );
    }

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

    function test_collectMint_revertsWhenFeeOnTransferTokenUnderpaysRecipient() public {
        FeeOnTransferERC20 feeToken = new FeeOnTransferERC20(accounts.owner.addr);
        feeToken.mint(accounts.buyer.addr, 1_000);
        bytes32 activationId = keccak256("activation");

        vm.prank(address(controller));
        erc20Payment.configure(
            activationId, abi.encode(ERC20PaymentModule.Params({token: feeToken, recipient: accounts.treasury.addr}))
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.payer = accounts.buyer.addr;

        vm.prank(accounts.buyer.addr);
        feeToken.approve(address(erc20Payment), 100);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20PaymentModule.PaymentAmountMismatch.selector, address(feeToken), accounts.treasury.addr, 100, 90
            )
        );
        vm.prank(address(controller));
        erc20Payment.collectMint(ctx, NamespaceTypes.Price({token: address(feeToken), amount: 100}), "");
    }

    function test_collectRenew_revertsForNativeValueAndTokenMismatch() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        erc20Payment.configure(
            activationId, abi.encode(ERC20PaymentModule.Params({token: token, recipient: accounts.treasury.addr}))
        );

        NamespaceTypes.RenewContext memory ctx;
        ctx.activationId = activationId;
        ctx.payer = accounts.buyer.addr;

        vm.deal(address(controller), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(ERC20PaymentModule.NativeValueNotAccepted.selector, 1));
        vm.prank(address(controller));
        erc20Payment.collectRenew{value: 1}(ctx, NamespaceTypes.Price({token: address(token), amount: 0}), "");

        vm.expectRevert(
            abi.encodeWithSelector(ERC20PaymentModule.PaymentTokenMismatch.selector, address(token), address(0xBEEF))
        );
        vm.prank(address(controller));
        erc20Payment.collectRenew(ctx, NamespaceTypes.Price({token: address(0xBEEF), amount: 0}), "");
    }

    function test_collectMint_revertsFromNonController() public {
        NamespaceTypes.MintContext memory ctx;

        vm.expectRevert();
        erc20Payment.collectMint(ctx, NamespaceTypes.Price({token: address(token), amount: 100}), "");
    }
}
