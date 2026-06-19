// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {Vm} from "forge-std/Vm.sol";

import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ReservationRule} from "src/modules/rules/ReservationRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract NamespaceControllerMintRenewTest is NamespaceSetUp {
    function test_mint_runsModulesCollectsPaymentAndRegistersLabel() public {
        bytes32 activationId = _activateDefault();
        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        uint256 tokenId = controller.mint(activationId, "pay", 365 days, runtimeData);
        vm.stopPrank();

        uint256 labelId = uint256(keccak256(bytes("pay")));
        assertEq(token.balanceOf(accounts.treasury.addr), 100 ether);
        IPermissionedRegistry.State memory state = registry.getState(labelId);
        assertEq(tokenId, state.tokenId);
        assertEq(registry.ownerOf(tokenId), accounts.buyer.addr);
        assertEq(registry.getResolver("pay"), address(0xBEEF));
        assertEq(registry.roles(tokenId, accounts.buyer.addr), BUYER_ROLES);

        assertEq(uint256(state.status), uint256(IPermissionedRegistry.Status.REGISTERED));
        assertEq(state.latestOwner, accounts.buyer.addr);

        assertEq(postHook.lastActivationId(), activationId);
        assertEq(postHook.lastBuyer(), accounts.buyer.addr);
        assertEq(postHook.lastLabelHash(), bytes32(labelId));
        assertEq(postHook.lastTokenId(), tokenId);
        assertEq(postHook.lastRuntimeData(), hex"1234");
    }

    function test_mint_revertsWhenRuntimeRuleDataLengthDoesNotMatch() public {
        bytes32 activationId = _activateDefault();
        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();
        runtimeData.ruleData = new bytes[](1);

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.RuntimeDataLengthMismatch.selector, controller.MODULE_KIND_RULE(), 3, 1
            )
        );
        controller.mint(activationId, "pay", 365 days, runtimeData);
        vm.stopPrank();
    }

    function test_renew_runsModulesCollectsPaymentAndExtendsExpiry() public {
        bytes32 activationId = _activateDefault();
        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 150 ether);
        uint256 tokenId = controller.mint(activationId, "pay", 365 days, runtimeData);

        IPermissionedRegistry.State memory beforeRenew = registry.getState(tokenId);
        uint64 newExpiry = controller.renew(activationId, "pay", 30 days, runtimeData);
        vm.stopPrank();

        IPermissionedRegistry.State memory afterRenew = registry.getState(tokenId);
        assertEq(newExpiry, beforeRenew.expiry + 30 days);
        assertEq(afterRenew.expiry, newExpiry);
        assertEq(token.balanceOf(accounts.treasury.addr), 150 ether);
    }

    function test_renew_revertsWhenLabelIsAvailable() public {
        bytes32 activationId = _activateDefault();
        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 50 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.LabelNotRenewable.selector, "pay", IPermissionedRegistry.Status.AVAILABLE
            )
        );
        controller.renew(activationId, "pay", 30 days, runtimeData);
        vm.stopPrank();
    }

    function test_mint_respectsReservationRule() public {
        ReservationRule reservationRule = ReservationRule(_deployModule(address(new ReservationRule())));
        Vm.Wallet memory reservedBuyer = vm.createWallet("reservedBuyer");
        token.mint(reservedBuyer.addr, 1_000 ether);
        bytes32 ruleKind = controller.MODULE_KIND_RULE();

        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(ruleKind, address(reservationRule), true);

        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        uint64 expiry = uint64(block.timestamp + 1 days);
        bytes32 labelHash = keccak256(bytes("vip"));
        ReservationRule.Claim memory claim = ReservationRule.Claim({
            labelHash: labelHash,
            account: reservedBuyer.addr,
            startTime: 0,
            endTime: expiry,
            mintable: true,
            token: address(0),
            mintPrice: 0,
            renewPrice: 0,
            priceOp: NamespaceTypes.PriceOp.NONE,
            proof: new bytes32[](0)
        });
        bytes32 reservationRoot = reservationRule.leaf(claim);
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](4);
        rules[0] = config.rules[0];
        rules[1] = config.rules[1];
        rules[2] = NamespaceTypes.RuleConfig({
            module: address(reservationRule),
            phase: NamespaceTypes.RulePhase.ELIGIBILITY,
            configData: abi.encode(ReservationRule.Params({root: reservationRoot}))
        });
        rules[3] = config.rules[2];
        config.rules = rules;

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();
        runtimeData.ruleData = new bytes[](4);
        runtimeData.ruleData[2] = abi.encode(claim);

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                ReservationRule.ReservedForDifferentAccount.selector,
                activationId,
                labelHash,
                reservedBuyer.addr,
                accounts.buyer.addr
            )
        );
        controller.mint(activationId, "vip", 365 days, runtimeData);
        vm.stopPrank();

        vm.startPrank(reservedBuyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        uint256 tokenId = controller.mint(activationId, "vip", 365 days, runtimeData);
        vm.stopPrank();

        assertEq(registry.ownerOf(tokenId), reservedBuyer.addr);
    }
}
