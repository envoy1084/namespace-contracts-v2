// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SSTORE2} from "solady/utils/SSTORE2.sol";

import {IRuleModule} from "src/interfaces/IRuleModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceControllerLifecycle} from "src/controller/NamespaceControllerLifecycle.sol";

/// @title NamespaceControllerRules
/// @notice Rule evaluation and price-effect application.
abstract contract NamespaceControllerRules is NamespaceControllerLifecycle {
    function _evaluateMintRules(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        bytes[] calldata ruleData
    ) internal returns (NamespaceTypes.Price memory price) {
        uint256 length = activation.ruleCount;
        EvaluationState memory state = EvaluationState({amount: 0, flags: 0, token: address(0), tokenSet: false});
        if (length == 0) return NamespaceTypes.Price({token: address(0), amount: 0});
        if (length == 1) {
            _applyRuleOutput(
                ctx.activationId,
                activation.rules,
                0,
                IRuleModule(activation.rules).evaluateMint(ctx, ruleData[0]),
                state
            );
            return NamespaceTypes.Price({token: state.token, amount: state.amount});
        }
        bytes memory rules = SSTORE2.read(activation.rules);
        for (uint256 i; i < length;) {
            address rule = _ruleAt(rules, i).module;
            _applyRuleOutput(ctx.activationId, rule, i, IRuleModule(rule).evaluateMint(ctx, ruleData[i]), state);
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
        EvaluationState memory state = EvaluationState({amount: 0, flags: 0, token: address(0), tokenSet: false});
        if (length == 0) return NamespaceTypes.Price({token: address(0), amount: 0});
        if (length == 1) {
            _applyRuleOutput(
                ctx.activationId,
                activation.rules,
                0,
                IRuleModule(activation.rules).evaluateRenew(ctx, ruleData[0]),
                state
            );
            return NamespaceTypes.Price({token: state.token, amount: state.amount});
        }
        bytes memory rules = SSTORE2.read(activation.rules);
        for (uint256 i; i < length;) {
            address rule = _ruleAt(rules, i).module;
            _applyRuleOutput(ctx.activationId, rule, i, IRuleModule(rule).evaluateRenew(ctx, ruleData[i]), state);
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

        if (
            op == NamespaceTypes.PriceOp.SET_BASE || op == NamespaceTypes.PriceOp.ADD
                || op == NamespaceTypes.PriceOp.SUBTRACT || op == NamespaceTypes.PriceOp.MIN
                || op == NamespaceTypes.PriceOp.MAX || op == NamespaceTypes.PriceOp.OVERRIDE
        ) {
            _applyToken(output.token, state);
        }

        if (op == NamespaceTypes.PriceOp.SET_BASE || op == NamespaceTypes.PriceOp.OVERRIDE) {
            state.amount = output.amount;
        } else if (op == NamespaceTypes.PriceOp.ADD) {
            state.amount += output.amount;
        } else if (op == NamespaceTypes.PriceOp.SUBTRACT) {
            state.amount = output.amount > state.amount ? 0 : state.amount - output.amount;
        } else if (op == NamespaceTypes.PriceOp.DISCOUNT_BPS) {
            _checkBps(rule, output.bps);
            state.amount = (state.amount * (BPS_DENOMINATOR - output.bps)) / BPS_DENOMINATOR;
        } else if (op == NamespaceTypes.PriceOp.MARKUP_BPS) {
            _checkBps(rule, output.bps);
            state.amount = (state.amount * (BPS_DENOMINATOR + output.bps)) / BPS_DENOMINATOR;
        } else if (op == NamespaceTypes.PriceOp.MIN) {
            if (state.amount < output.amount) state.amount = output.amount;
        } else if (op == NamespaceTypes.PriceOp.MAX && state.amount > output.amount) {
            state.amount = output.amount;
        }
    }
    // slither-disable-end cyclomatic-complexity
    // slither-disable-end incorrect-equality

    function _applyToken(address token, EvaluationState memory state) private pure {
        if (!state.tokenSet) {
            state.token = token;
            state.tokenSet = true;
            return;
        }
        if (state.token != token) revert RulePaymentTokenMismatch(state.token, token);
    }

    function _checkBps(address rule, uint16 bps) private pure {
        if (bps > BPS_DENOMINATOR) revert InvalidRuleBps(rule, bps);
    }
}
