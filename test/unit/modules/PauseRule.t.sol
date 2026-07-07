// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {PauseRule} from "src/modules/rules/PauseRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract PauseRuleTest is NamespaceSetUp {
    PauseRule internal pauseRule;

    function setUp() public override {
        super.setUp();
        pauseRule = PauseRule(_deployModule(address(new PauseRule())));

        bytes32 ruleKind = controller.MODULE_KIND_RULE();
        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(ruleKind, address(pauseRule), true);
    }

    function test_setPaused_allowsActivationOwner() public {
        bytes32 activationId = _activateWithPauseRule();

        vm.prank(accounts.alice.addr);
        pauseRule.setPaused(activationId, true);

        assertTrue(pauseRule.paused(activationId));
    }

    function test_setPaused_revertsForNonActivationOwner() public {
        bytes32 activationId = _activateWithPauseRule();

        vm.expectRevert(
            abi.encodeWithSelector(
                PauseRule.NotActivationOwner.selector, activationId, accounts.buyer.addr, accounts.alice.addr
            )
        );
        vm.prank(accounts.buyer.addr);
        pauseRule.setPaused(activationId, true);
    }

    function test_evaluateMintAndRenew_revertWhenPaused() public {
        bytes32 activationId = _activateWithPauseRule();

        vm.prank(accounts.alice.addr);
        pauseRule.setPaused(activationId, true);

        NamespaceTypes.MintContext memory mintCtx;
        mintCtx.activationId = activationId;

        vm.expectRevert(abi.encodeWithSelector(PauseRule.ActivationPaused.selector, activationId));
        pauseRule.evaluateMint(mintCtx, "");

        NamespaceTypes.RenewContext memory renewCtx;
        renewCtx.activationId = activationId;

        vm.expectRevert(abi.encodeWithSelector(PauseRule.ActivationPaused.selector, activationId));
        pauseRule.evaluateRenew(renewCtx, "");
    }

    function test_evaluateMint_allowsAfterUnpause() public {
        bytes32 activationId = _activateWithPauseRule();

        vm.startPrank(accounts.alice.addr);
        pauseRule.setPaused(activationId, true);
        pauseRule.setPaused(activationId, false);
        vm.stopPrank();

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        NamespaceTypes.RuleOutput memory output = pauseRule.evaluateMint(ctx, "");
        assertEq(uint256(output.decision), uint256(NamespaceTypes.Decision.PASS));
    }

    function test_evaluateRenew_allowsWhenUnpaused() public {
        bytes32 activationId = _activateWithPauseRule();

        NamespaceTypes.RenewContext memory ctx;
        ctx.activationId = activationId;

        NamespaceTypes.RuleOutput memory output = pauseRule.evaluateRenew(ctx, "");
        assertEq(uint256(output.decision), uint256(NamespaceTypes.Decision.PASS));
    }

    function _activateWithPauseRule() private returns (bytes32 activationId) {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](4);
        rules[0] = NamespaceTypes.RuleConfig({
            module: address(pauseRule), phase: NamespaceTypes.RulePhase.GUARD, configData: ""
        });
        rules[1] = config.rules[0];
        rules[2] = config.rules[1];
        rules[3] = config.rules[2];
        config.rules = rules;

        vm.prank(accounts.alice.addr);
        activationId = controller.activate(config);
    }
}
