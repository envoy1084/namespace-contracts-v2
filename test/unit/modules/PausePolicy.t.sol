// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {PausePolicy} from "src/modules/policies/PausePolicy.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract PausePolicyTest is NamespaceSetUp {
    PausePolicy internal pausePolicy;

    function setUp() public override {
        super.setUp();
        pausePolicy = new PausePolicy(address(controller));
        bytes32 policyKind = controller.MODULE_KIND_POLICY();

        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(policyKind, address(pausePolicy), true);
    }

    function test_setPaused_allowsActivationOwner() public {
        bytes32 activationId = _activateWithPausePolicy();

        vm.prank(accounts.alice.addr);
        pausePolicy.setPaused(activationId, true);

        assertTrue(pausePolicy.paused(activationId));
    }

    function test_setPaused_revertsForNonActivationOwner() public {
        bytes32 activationId = _activateWithPausePolicy();

        vm.expectRevert(
            abi.encodeWithSelector(
                PausePolicy.NotActivationOwner.selector, activationId, accounts.buyer.addr, accounts.alice.addr
            )
        );
        vm.prank(accounts.buyer.addr);
        pausePolicy.setPaused(activationId, true);
    }

    function test_checkMintAndRenew_revertWhenPaused() public {
        bytes32 activationId = _activateWithPausePolicy();

        vm.prank(accounts.alice.addr);
        pausePolicy.setPaused(activationId, true);

        NamespaceTypes.MintContext memory mintCtx;
        mintCtx.activationId = activationId;

        vm.expectRevert(abi.encodeWithSelector(PausePolicy.ActivationPaused.selector, activationId));
        pausePolicy.checkMint(mintCtx, "");

        NamespaceTypes.RenewContext memory renewCtx;
        renewCtx.activationId = activationId;

        vm.expectRevert(abi.encodeWithSelector(PausePolicy.ActivationPaused.selector, activationId));
        pausePolicy.checkRenew(renewCtx, "");
    }

    function test_checkMint_allowsAfterUnpause() public {
        bytes32 activationId = _activateWithPausePolicy();

        vm.startPrank(accounts.alice.addr);
        pausePolicy.setPaused(activationId, true);
        pausePolicy.setPaused(activationId, false);
        vm.stopPrank();

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        pausePolicy.checkMint(ctx, "");
    }

    function _activateWithPausePolicy() private returns (bytes32 activationId) {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        NamespaceTypes.ModuleConfig[] memory policies = new NamespaceTypes.ModuleConfig[](3);
        policies[0] = NamespaceTypes.ModuleConfig({module: address(pausePolicy), configData: ""});
        policies[1] = config.policies[0];
        policies[2] = config.policies[1];
        config.policies = policies;

        vm.prank(accounts.alice.addr);
        activationId = controller.activate(config);
    }
}
