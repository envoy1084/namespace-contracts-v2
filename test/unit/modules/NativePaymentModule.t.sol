// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NativePaymentModule} from "src/modules/payment/NativePaymentModule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract NativePaymentModuleTest is NamespaceSetUp {
    NativePaymentModule internal payment;

    function setUp() public override {
        super.setUp();
        payment = NativePaymentModule(_deployModule(address(new NativePaymentModule())));
    }

    function test_configure_revertsForInvalidRecipient() public {
        bytes32 activationId = keccak256("activation");

        vm.expectRevert(abi.encodeWithSelector(NativePaymentModule.InvalidPaymentRecipient.selector));
        vm.prank(address(controller));
        payment.configure(activationId, abi.encode(NativePaymentModule.Params({recipient: address(0)})));
    }

    function test_collectMint_transfersNativePaymentToRecipient() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        payment.configure(activationId, abi.encode(NativePaymentModule.Params({recipient: accounts.treasury.addr})));

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        uint256 beforeBalance = accounts.treasury.addr.balance;
        vm.deal(address(controller), 100);
        vm.prank(address(controller));
        payment.collectMint{value: 100}(ctx, NamespaceTypes.Price({token: address(0), amount: 100}), "");

        assertEq(accounts.treasury.addr.balance - beforeBalance, 100);
    }

    function test_collectRenew_revertsForTokenMismatchAndAmountMismatch() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        payment.configure(activationId, abi.encode(NativePaymentModule.Params({recipient: accounts.treasury.addr})));

        NamespaceTypes.RenewContext memory ctx;
        ctx.activationId = activationId;

        vm.expectRevert(
            abi.encodeWithSelector(NativePaymentModule.PaymentTokenMismatch.selector, address(0), address(token))
        );
        vm.prank(address(controller));
        payment.collectRenew(ctx, NamespaceTypes.Price({token: address(token), amount: 0}), "");

        vm.deal(address(controller), 99);
        vm.expectRevert(abi.encodeWithSelector(NativePaymentModule.NativePaymentAmountMismatch.selector, 100, 99));
        vm.prank(address(controller));
        payment.collectRenew{value: 99}(ctx, NamespaceTypes.Price({token: address(0), amount: 100}), "");
    }

    function test_collectMint_revertsFromNonController() public {
        NamespaceTypes.MintContext memory ctx;

        vm.expectRevert();
        payment.collectMint(ctx, NamespaceTypes.Price({token: address(0), amount: 100}), "");
    }
}
