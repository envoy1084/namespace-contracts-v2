// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";
import {OutputRule} from "test/mocks/OutputRule.sol";

contract NamespaceControllerStrictRulesTest is NamespaceSetUp {
    function test_mint_revertsWhenGuardRuleReturnsPriceOperation() public {
        OutputRule rule = _deployOutputRule();
        NamespaceTypes.RuleOutput memory output = _priceOutput(NamespaceTypes.PriceOp.SET_BASE, 100 ether);
        NamespaceTypes.RuleConfig[] memory rules = _singleRule(rule, NamespaceTypes.RulePhase.GUARD, output);
        bytes32 activationId = _activateRules(rules, _noPaymentModule());

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.RuleOperationNotAllowed.selector,
                activationId,
                address(rule),
                0,
                NamespaceTypes.RulePhase.GUARD,
                NamespaceTypes.PriceOp.SET_BASE
            )
        );
        vm.prank(accounts.buyer.addr);
        controller.mint(activationId, "pay", 365 days, _runtimeData(1));
    }

    function test_mint_revertsWhenBasePriceIsSetTwice() public {
        OutputRule firstRule = _deployOutputRule();
        OutputRule secondRule = _deployOutputRule();
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](2);
        rules[0] = _ruleConfig(
            firstRule, NamespaceTypes.RulePhase.BASE_PRICE, _priceOutput(NamespaceTypes.PriceOp.SET_BASE, 100 ether)
        );
        rules[1] = _ruleConfig(
            secondRule, NamespaceTypes.RulePhase.BASE_PRICE, _priceOutput(NamespaceTypes.PriceOp.SET_BASE, 200 ether)
        );
        bytes32 activationId = _activateRules(rules, _noPaymentModule());

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.RuleBasePriceAlreadySet.selector, activationId, address(secondRule), 1
            )
        );
        vm.prank(accounts.buyer.addr);
        controller.mint(activationId, "pay", 365 days, _runtimeData(2));
    }

    function test_mint_revertsWhenDiscountRunsBeforePriceExists() public {
        OutputRule rule = _deployOutputRule();
        NamespaceTypes.RuleOutput memory output;
        output.decision = NamespaceTypes.Decision.PASS;
        output.priceOp = NamespaceTypes.PriceOp.DISCOUNT_BPS;
        output.bps = 1000;

        NamespaceTypes.RuleConfig[] memory rules = _singleRule(rule, NamespaceTypes.RulePhase.DISCOUNT, output);
        bytes32 activationId = _activateRules(rules, _noPaymentModule());

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.RulePriceOperationBeforePrice.selector,
                activationId,
                address(rule),
                0,
                NamespaceTypes.PriceOp.DISCOUNT_BPS
            )
        );
        vm.prank(accounts.buyer.addr);
        controller.mint(activationId, "pay", 365 days, _runtimeData(1));
    }

    function test_mint_revertsWhenRuleChangesPriceAfterOverride() public {
        OutputRule overrideRule = _deployOutputRule();
        OutputRule finalRule = _deployOutputRule();
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](2);
        rules[0] = _ruleConfig(
            overrideRule, NamespaceTypes.RulePhase.OVERRIDE, _priceOutput(NamespaceTypes.PriceOp.OVERRIDE, 100 ether)
        );
        rules[1] = _ruleConfig(
            finalRule, NamespaceTypes.RulePhase.FINAL_CHECK, _priceOutput(NamespaceTypes.PriceOp.MIN, 200 ether)
        );
        bytes32 activationId = _activateRules(rules, _noPaymentModule());

        vm.expectRevert(
            abi.encodeWithSelector(
                INamespaceController.RulePriceAlreadyOverridden.selector, activationId, address(finalRule), 1
            )
        );
        vm.prank(accounts.buyer.addr);
        controller.mint(activationId, "pay", 365 days, _runtimeData(2));
    }

    function test_mint_allowsBasePriceThenDiscount() public {
        OutputRule baseRule = _deployOutputRule();
        OutputRule discountRule = _deployOutputRule();
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](2);
        rules[0] = _ruleConfig(
            baseRule, NamespaceTypes.RulePhase.BASE_PRICE, _priceOutput(NamespaceTypes.PriceOp.SET_BASE, 100 ether)
        );

        NamespaceTypes.RuleOutput memory discountOutput;
        discountOutput.decision = NamespaceTypes.Decision.PASS;
        discountOutput.priceOp = NamespaceTypes.PriceOp.DISCOUNT_BPS;
        discountOutput.bps = 5000;
        rules[1] = _ruleConfig(discountRule, NamespaceTypes.RulePhase.DISCOUNT, discountOutput);

        bytes32 activationId = _activateRules(rules, _erc20PaymentModule());

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 50 ether);
        uint256 tokenId = controller.mint(activationId, "pay", 365 days, _runtimeData(2));
        vm.stopPrank();

        assertEq(token.balanceOf(accounts.treasury.addr), 50 ether);
        assertEq(registry.ownerOf(tokenId), accounts.buyer.addr);
    }

    function _deployOutputRule() private returns (OutputRule rule) {
        rule = OutputRule(_deployModule(address(new OutputRule())));
        bytes32 ruleKind = controller.MODULE_KIND_RULE();
        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(ruleKind, address(rule), true);
    }

    function _activateRules(NamespaceTypes.RuleConfig[] memory rules, NamespaceTypes.ModuleConfig memory paymentModule)
        private
        returns (bytes32 activationId)
    {
        NamespaceTypes.ModuleConfig[] memory postHooks = new NamespaceTypes.ModuleConfig[](0);
        NamespaceTypes.ActivationConfig memory config = NamespaceTypes.ActivationConfig({
            registry: IPermissionedRegistry(address(registry)),
            parentNode: keccak256("alice.eth"),
            resolver: address(0xBEEF),
            buyerRoleBitmap: BUYER_ROLES,
            rules: rules,
            paymentModule: paymentModule,
            postHooks: postHooks
        });

        vm.prank(accounts.alice.addr);
        activationId = controller.activate(config);
    }

    function _singleRule(OutputRule rule, NamespaceTypes.RulePhase phase, NamespaceTypes.RuleOutput memory output)
        private
        pure
        returns (NamespaceTypes.RuleConfig[] memory rules)
    {
        rules = new NamespaceTypes.RuleConfig[](1);
        rules[0] = _ruleConfig(rule, phase, output);
    }

    function _ruleConfig(OutputRule rule, NamespaceTypes.RulePhase phase, NamespaceTypes.RuleOutput memory output)
        private
        pure
        returns (NamespaceTypes.RuleConfig memory config)
    {
        config = NamespaceTypes.RuleConfig({module: address(rule), phase: phase, configData: abi.encode(output)});
    }

    function _runtimeData(uint256 ruleCount) private pure returns (NamespaceTypes.RuntimeData memory runtimeData) {
        runtimeData.ruleData = new bytes[](ruleCount);
        runtimeData.paymentData = "";
        runtimeData.postHookData = new bytes[](0);
    }

    function _priceOutput(NamespaceTypes.PriceOp op, uint256 amount)
        private
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        output.decision = NamespaceTypes.Decision.PASS;
        output.priceOp = op;
        output.token = address(token);
        output.amount = amount;
    }

    function _noPaymentModule() private pure returns (NamespaceTypes.ModuleConfig memory paymentModule) {
        paymentModule = NamespaceTypes.ModuleConfig({module: address(0), configData: ""});
    }

    function _erc20PaymentModule() private view returns (NamespaceTypes.ModuleConfig memory paymentModule) {
        paymentModule = NamespaceTypes.ModuleConfig({
            module: address(erc20Payment),
            configData: abi.encode(ERC20PaymentModule.Params({token: token, recipient: accounts.treasury.addr}))
        });
    }
}
