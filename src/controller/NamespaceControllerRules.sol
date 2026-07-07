// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SSTORE2} from "solady/utils/SSTORE2.sol";

import {IRuleModule} from "src/interfaces/IRuleModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceControllerLifecycle} from "src/controller/NamespaceControllerLifecycle.sol";

/// @title NamespaceControllerRules
/// @notice Rule evaluation and price-effect application.
abstract contract NamespaceControllerRules is NamespaceControllerLifecycle {
    uint256 private constant STATUS_TOKEN_SET = 1 << 0;
    uint256 private constant STATUS_BASE_SET = 1 << 1;
    uint256 private constant STATUS_PRICE_MUTATED = 1 << 2;
    uint256 private constant STATUS_OVERRIDDEN = 1 << 3;
    uint256 private constant STATUS_DISCOUNTED = 1 << 4;

    function _evaluateMintRules(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        bytes[] calldata ruleData
    ) internal returns (NamespaceTypes.Price memory price) {
        uint256 length = activation.ruleCount;
        if (length == 0) return NamespaceTypes.Price({token: address(0), amount: 0});
        EvaluationState memory state = EvaluationState({amount: 0, flags: 0, token: address(0), status: 0});
        if (length == 1) {
            address rule = activation.rules;
            _checkModule(rule, MODULE_KIND_RULE);
            _applyRuleOutput(
                ctx.activationId,
                rule,
                0,
                NamespaceTypes.RulePhase(activation.firstRulePhase),
                IRuleModule(rule).evaluateMint(ctx, ruleData[0]),
                state
            );
            return NamespaceTypes.Price({token: state.token, amount: state.amount});
        }
        bytes memory rules = SSTORE2.read(activation.rules);
        for (uint256 i; i < length;) {
            RuleRef memory ref = _ruleAt(rules, i);
            _checkModule(ref.module, MODULE_KIND_RULE);
            _applyRuleOutput(
                ctx.activationId,
                ref.module,
                i,
                ref.phase,
                IRuleModule(ref.module).evaluateMint(ctx, ruleData[i]),
                state
            );
            unchecked {
                ++i;
            }
        }
        price = NamespaceTypes.Price({token: state.token, amount: state.amount});
    }

    function _evaluateRenewRules(
        ActivationData storage activation,
        NamespaceTypes.RenewContext memory ctx,
        bytes[] calldata ruleData
    ) internal returns (NamespaceTypes.Price memory price) {
        uint256 length = activation.ruleCount;
        if (length == 0) return NamespaceTypes.Price({token: address(0), amount: 0});
        EvaluationState memory state = EvaluationState({amount: 0, flags: 0, token: address(0), status: 0});
        if (length == 1) {
            address rule = activation.rules;
            _checkModule(rule, MODULE_KIND_RULE);
            _applyRuleOutput(
                ctx.activationId,
                rule,
                0,
                NamespaceTypes.RulePhase(activation.firstRulePhase),
                IRuleModule(rule).evaluateRenew(ctx, ruleData[0]),
                state
            );
            return NamespaceTypes.Price({token: state.token, amount: state.amount});
        }
        bytes memory rules = SSTORE2.read(activation.rules);
        for (uint256 i; i < length;) {
            RuleRef memory ref = _ruleAt(rules, i);
            _checkModule(ref.module, MODULE_KIND_RULE);
            _applyRuleOutput(
                ctx.activationId,
                ref.module,
                i,
                ref.phase,
                IRuleModule(ref.module).evaluateRenew(ctx, ruleData[i]),
                state
            );
            unchecked {
                ++i;
            }
        }
        price = NamespaceTypes.Price({token: state.token, amount: state.amount});
    }

    function _mintContext(
        ActivationData storage activation,
        bytes32 activationId,
        string calldata label,
        uint256 labelId,
        uint64 duration
    ) internal view returns (NamespaceTypes.MintContext memory ctx) {
        ctx = NamespaceTypes.MintContext({
            activationId: activationId,
            buyer: msg.sender,
            payer: msg.sender,
            registry: activation.registry,
            parentNode: activation.parentNode,
            label: label,
            labelHash: bytes32(labelId),
            duration: duration,
            expiry: uint64(block.timestamp) + duration,
            resolver: activation.resolver,
            buyerRoleBitmap: activation.buyerRoleBitmap
        });
    }

    // slither-disable-start incorrect-equality
    // slither-disable-start cyclomatic-complexity
    // solhint-disable-next-line function-max-lines
    function _applyRuleOutput(
        bytes32 activationId,
        address rule,
        uint256 index,
        NamespaceTypes.RulePhase phase,
        NamespaceTypes.RuleOutput memory output,
        EvaluationState memory state
    ) internal pure {
        if (output.requireFlags != 0 && (state.flags & output.requireFlags) != output.requireFlags) {
            revert RequiredRuleFlagsMissing(activationId, rule, index, output.requireFlags, state.flags);
        }
        if (output.decision == NamespaceTypes.Decision.BLOCK) revert RuleBlocked(activationId, rule, index);
        if (output.decision == NamespaceTypes.Decision.SKIP) return;

        state.flags |= output.addFlags;

        NamespaceTypes.PriceOp op = output.priceOp;
        if (op == NamespaceTypes.PriceOp.NONE) return;

        _checkPhaseOperation(activationId, rule, index, phase, op);
        _checkPriceState(activationId, rule, index, op, state.status);

        if (
            op == NamespaceTypes.PriceOp.SET_BASE || op == NamespaceTypes.PriceOp.ADD
                || op == NamespaceTypes.PriceOp.SUBTRACT || op == NamespaceTypes.PriceOp.MIN
                || op == NamespaceTypes.PriceOp.MAX || op == NamespaceTypes.PriceOp.OVERRIDE
        ) {
            _applyToken(output.token, state);
        }

        if (op == NamespaceTypes.PriceOp.SET_BASE || op == NamespaceTypes.PriceOp.OVERRIDE) {
            state.amount = output.amount;
            state.status |= op == NamespaceTypes.PriceOp.SET_BASE
                ? STATUS_BASE_SET | STATUS_PRICE_MUTATED
                : STATUS_PRICE_MUTATED | STATUS_OVERRIDDEN;
        } else if (op == NamespaceTypes.PriceOp.ADD) {
            state.amount += output.amount;
            state.status |= STATUS_PRICE_MUTATED;
        } else if (op == NamespaceTypes.PriceOp.SUBTRACT) {
            state.amount = output.amount > state.amount ? 0 : state.amount - output.amount;
            state.status |= STATUS_PRICE_MUTATED | STATUS_DISCOUNTED;
        } else if (op == NamespaceTypes.PriceOp.DISCOUNT_BPS) {
            _checkBps(rule, output.bps);
            state.amount = (state.amount * (BPS_DENOMINATOR - output.bps)) / BPS_DENOMINATOR;
            state.status |= STATUS_PRICE_MUTATED | STATUS_DISCOUNTED;
        } else if (op == NamespaceTypes.PriceOp.MARKUP_BPS) {
            _checkBps(rule, output.bps);
            state.amount = (state.amount * (BPS_DENOMINATOR + output.bps)) / BPS_DENOMINATOR;
            state.status |= STATUS_PRICE_MUTATED;
        } else if (op == NamespaceTypes.PriceOp.MIN) {
            if (state.amount < output.amount) state.amount = output.amount;
            state.status |= STATUS_PRICE_MUTATED;
        } else if (op == NamespaceTypes.PriceOp.MAX && state.amount > output.amount) {
            state.amount = output.amount;
            state.status |= STATUS_PRICE_MUTATED;
        }
    }

    // slither-disable-end cyclomatic-complexity
    function _applyToken(address token, EvaluationState memory state) private pure {
        if ((state.status & STATUS_TOKEN_SET) == 0) {
            state.token = token;
            state.status |= STATUS_TOKEN_SET;
            return;
        }
        if (state.token != token) revert RulePaymentTokenMismatch(state.token, token);
    }

    function _checkPhaseOperation(
        bytes32 activationId,
        address rule,
        uint256 index,
        NamespaceTypes.RulePhase phase,
        NamespaceTypes.PriceOp op
    ) private pure {
        if (_phaseAllowsOperation(phase, op)) return;
        revert RuleOperationNotAllowed(activationId, rule, index, phase, op);
    }

    function _phaseAllowsOperation(NamespaceTypes.RulePhase phase, NamespaceTypes.PriceOp op)
        private
        pure
        returns (bool)
    {
        if (phase == NamespaceTypes.RulePhase.BASE_PRICE) {
            return op == NamespaceTypes.PriceOp.SET_BASE;
        }
        if (phase == NamespaceTypes.RulePhase.PREMIUM) {
            return op == NamespaceTypes.PriceOp.ADD || op == NamespaceTypes.PriceOp.MARKUP_BPS
                || op == NamespaceTypes.PriceOp.MIN;
        }
        if (phase == NamespaceTypes.RulePhase.DISCOUNT) {
            return op == NamespaceTypes.PriceOp.SUBTRACT || op == NamespaceTypes.PriceOp.DISCOUNT_BPS
                || op == NamespaceTypes.PriceOp.MAX;
        }
        if (phase == NamespaceTypes.RulePhase.OVERRIDE) {
            return op == NamespaceTypes.PriceOp.OVERRIDE;
        }
        if (phase == NamespaceTypes.RulePhase.FINAL_CHECK) {
            return op == NamespaceTypes.PriceOp.MIN || op == NamespaceTypes.PriceOp.MAX;
        }
        return false;
    }

    function _checkPriceState(
        bytes32 activationId,
        address rule,
        uint256 index,
        NamespaceTypes.PriceOp op,
        uint256 status
    ) private pure {
        if ((status & STATUS_OVERRIDDEN) != 0) {
            revert RulePriceAlreadyOverridden(activationId, rule, index);
        }
        if (op == NamespaceTypes.PriceOp.SET_BASE && (status & STATUS_BASE_SET) != 0) {
            revert RuleBasePriceAlreadySet(activationId, rule, index);
        }
        if (
            (op == NamespaceTypes.PriceOp.SUBTRACT
                    || op == NamespaceTypes.PriceOp.DISCOUNT_BPS
                    || op == NamespaceTypes.PriceOp.MARKUP_BPS
                    || op == NamespaceTypes.PriceOp.MAX) && (status & STATUS_PRICE_MUTATED) == 0
        ) {
            revert RulePriceOperationBeforePrice(activationId, rule, index, op);
        }
    }
    // slither-disable-end incorrect-equality

    function _checkBps(address rule, uint16 bps) private pure {
        if (bps > BPS_DENOMINATOR) revert InvalidRuleBps(rule, bps);
    }
}
