// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20SplitPaymentModule} from "src/modules/payment/ERC20SplitPaymentModule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";
import {FeeOnTransferERC20} from "test/mocks/FeeOnTransferERC20.sol";

contract ERC20SplitPaymentModuleTest is NamespaceSetUp {
    ERC20SplitPaymentModule internal payment;

    function setUp() public override {
        super.setUp();
        payment = ERC20SplitPaymentModule(_deployModule(address(new ERC20SplitPaymentModule())));
    }

    function test_collectMint_transfersPaymentDirectlyToSplitRecipients() public {
        bytes32 activationId = keccak256("activation");
        ERC20SplitPaymentModule.Split[] memory splits = new ERC20SplitPaymentModule.Split[](2);
        splits[0] = ERC20SplitPaymentModule.Split({recipient: accounts.alice.addr, bps: 7500});
        splits[1] = ERC20SplitPaymentModule.Split({recipient: accounts.treasury.addr, bps: 2500});

        vm.prank(address(controller));
        payment.configure(
            activationId, abi.encode(ERC20SplitPaymentModule.Params({token: address(token), splits: splits}))
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.payer = accounts.buyer.addr;

        vm.prank(accounts.buyer.addr);
        token.approve(address(payment), 100);

        uint256 aliceBefore = token.balanceOf(accounts.alice.addr);
        uint256 treasuryBefore = token.balanceOf(accounts.treasury.addr);

        vm.prank(address(controller));
        payment.collectMint(ctx, NamespaceTypes.Price({token: address(token), amount: 100}), "");

        assertEq(token.balanceOf(accounts.alice.addr) - aliceBefore, 75);
        assertEq(token.balanceOf(accounts.treasury.addr) - treasuryBefore, 25);

        assertEq(payment.token(activationId), address(token));
        assertEq(payment.splitCount(activationId), 2);
        ERC20SplitPaymentModule.Split memory split = payment.splitAt(activationId, 1);
        assertEq(split.recipient, accounts.treasury.addr);
        assertEq(split.bps, 2500);
    }

    function test_collectMint_revertsWhenFeeOnTransferTokenUnderpaysRecipients() public {
        FeeOnTransferERC20 feeToken = new FeeOnTransferERC20(accounts.owner.addr);
        feeToken.mint(accounts.buyer.addr, 1_000);
        bytes32 activationId = keccak256("activation");
        ERC20SplitPaymentModule.Split[] memory splits = new ERC20SplitPaymentModule.Split[](2);
        splits[0] = ERC20SplitPaymentModule.Split({recipient: accounts.alice.addr, bps: 5000});
        splits[1] = ERC20SplitPaymentModule.Split({recipient: accounts.treasury.addr, bps: 5000});

        vm.prank(address(controller));
        payment.configure(
            activationId, abi.encode(ERC20SplitPaymentModule.Params({token: address(feeToken), splits: splits}))
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.payer = accounts.buyer.addr;

        vm.prank(accounts.buyer.addr);
        feeToken.approve(address(payment), 100);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20SplitPaymentModule.PaymentAmountMismatch.selector, address(feeToken), accounts.alice.addr, 50, 45
            )
        );
        vm.prank(address(controller));
        payment.collectMint(ctx, NamespaceTypes.Price({token: address(feeToken), amount: 100}), "");
    }

    function test_configure_revertsForInvalidRecipientAndInvalidBps() public {
        bytes32 activationId = keccak256("activation");
        ERC20SplitPaymentModule.Split[] memory splits = new ERC20SplitPaymentModule.Split[](1);
        splits[0] = ERC20SplitPaymentModule.Split({recipient: accounts.alice.addr, bps: 10_000});

        vm.expectRevert(abi.encodeWithSelector(ERC20SplitPaymentModule.InvalidPaymentToken.selector));
        vm.prank(address(controller));
        payment.configure(activationId, abi.encode(ERC20SplitPaymentModule.Params({token: address(0), splits: splits})));

        splits[0] = ERC20SplitPaymentModule.Split({recipient: address(0), bps: 10_000});

        vm.expectRevert(abi.encodeWithSelector(ERC20SplitPaymentModule.InvalidSplitRecipient.selector));
        vm.prank(address(controller));
        payment.configure(
            activationId, abi.encode(ERC20SplitPaymentModule.Params({token: address(token), splits: splits}))
        );

        splits[0] = ERC20SplitPaymentModule.Split({recipient: accounts.alice.addr, bps: 9999});
        vm.expectRevert(abi.encodeWithSelector(ERC20SplitPaymentModule.InvalidSplitBps.selector, 9999));
        vm.prank(address(controller));
        payment.configure(
            activationId, abi.encode(ERC20SplitPaymentModule.Params({token: address(token), splits: splits}))
        );
    }

    function test_collectRenew_revertsForNativeValueAndTokenMismatch() public {
        bytes32 activationId = keccak256("activation");
        ERC20SplitPaymentModule.Split[] memory splits = new ERC20SplitPaymentModule.Split[](1);
        splits[0] = ERC20SplitPaymentModule.Split({recipient: accounts.alice.addr, bps: 10_000});

        vm.prank(address(controller));
        payment.configure(
            activationId, abi.encode(ERC20SplitPaymentModule.Params({token: address(token), splits: splits}))
        );

        NamespaceTypes.RenewContext memory ctx;
        ctx.activationId = activationId;
        ctx.payer = accounts.buyer.addr;

        vm.deal(address(controller), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(ERC20SplitPaymentModule.NativeValueNotAccepted.selector, 1));
        vm.prank(address(controller));
        payment.collectRenew{value: 1}(ctx, NamespaceTypes.Price({token: address(token), amount: 0}), "");

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20SplitPaymentModule.PaymentTokenMismatch.selector, address(token), address(0xBEEF)
            )
        );
        vm.prank(address(controller));
        payment.collectRenew(ctx, NamespaceTypes.Price({token: address(0xBEEF), amount: 0}), "");
    }

    function test_collectMint_revertsFromNonController() public {
        NamespaceTypes.MintContext memory ctx;

        vm.expectRevert();
        payment.collectMint(ctx, NamespaceTypes.Price({token: address(token), amount: 100}), "");
    }
}
