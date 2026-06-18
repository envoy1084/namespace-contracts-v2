// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20SplitPaymentModule} from "src/modules/payment/ERC20SplitPaymentModule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

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
    }

    function test_collectMint_revertsFromNonController() public {
        NamespaceTypes.MintContext memory ctx;

        vm.expectRevert();
        payment.collectMint(ctx, NamespaceTypes.Price({token: address(token), amount: 100}), "");
    }
}
