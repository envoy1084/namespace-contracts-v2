// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {SaleWindowRule} from "src/modules/rules/SaleWindowRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract NamespaceControllerModulesTest is NamespaceSetUp {
    function test_updateModuleConfig_allowsActivationOwner() public {
        bytes32 activationId = _activateDefault();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();

        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(
            activationId,
            ruleKind,
            0,
            abi.encode(
                SaleWindowRule.Params({startTime: uint64(block.timestamp + 1), endTime: uint64(block.timestamp + 2)})
            )
        );

        (uint64 startTime, uint64 endTime) = saleWindowRule.params(activationId);
        assertEq(startTime, uint64(block.timestamp + 1));
        assertEq(endTime, uint64(block.timestamp + 2));
    }

    function test_updateModuleConfig_revertsForNonActivationOwner() public {
        bytes32 activationId = _activateDefault();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.NotActivationOwner.selector, activationId, accounts.buyer.addr)
        );
        vm.prank(accounts.buyer.addr);
        controller.updateModuleConfig(
            activationId, ruleKind, 0, abi.encode(SaleWindowRule.Params({startTime: 1, endTime: 2}))
        );
    }

    function test_updateModuleConfig_revertsWhenOwnerLostRegistryAdmin() public {
        bytes32 activationId = _activateDefault();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();
        registry.revokeRootRoles(ROLE_REGISTRAR_ADMIN, accounts.alice.addr);

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.UnauthorizedActivationOwner.selector, accounts.alice.addr, address(registry)
            )
        );
        vm.prank(accounts.alice.addr);
        controller.updateModuleConfig(
            activationId, ruleKind, 0, abi.encode(SaleWindowRule.Params({startTime: 1, endTime: 2}))
        );
    }

    function test_activate_revertsWhenModuleApprovalRequiredAndModuleIsUnapproved() public {
        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        SaleWindowRule unapprovedRule = SaleWindowRule(_deployModule(address(new SaleWindowRule())));
        config.rules[0] = NamespaceTypes.RuleConfig({
            module: address(unapprovedRule),
            phase: NamespaceTypes.RulePhase.GUARD,
            configData: abi.encode(SaleWindowRule.Params({startTime: 0, endTime: 0}))
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.UnapprovedModule.selector, address(unapprovedRule), controller.MODULE_KIND_RULE()
            )
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }

    function test_activate_revertsWhenModuleIsApprovedForDifferentKind() public {
        bytes32 paymentKind = controller.MODULE_KIND_PAYMENT();
        bytes32 ruleKind = controller.MODULE_KIND_RULE();
        SaleWindowRule unapprovedRule = SaleWindowRule(_deployModule(address(new SaleWindowRule())));

        vm.prank(accounts.owner.addr);
        controller.setModuleApprovalRequired(true);

        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(paymentKind, address(unapprovedRule), true);

        NamespaceTypes.ActivationConfig memory config = _defaultActivationConfig();
        config.rules[0] = NamespaceTypes.RuleConfig({
            module: address(unapprovedRule),
            phase: NamespaceTypes.RulePhase.GUARD,
            configData: abi.encode(SaleWindowRule.Params({startTime: 0, endTime: 0}))
        });

        vm.expectRevert(
            abi.encodeWithSelector(INamespaceController.UnapprovedModule.selector, address(unapprovedRule), ruleKind)
        );
        vm.prank(accounts.alice.addr);
        controller.activate(config);
    }
}
