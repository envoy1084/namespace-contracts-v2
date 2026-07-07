// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceRule} from "src/modules/rules/NamespaceRule.sol";

/// @title TokenBalanceRule
/// @notice Requires an ERC20 balance and can apply a token-holder discount.
contract TokenBalanceRule is NamespaceRule {
    /// @notice Token balance rule params.
    /// @param token ERC20 token checked for eligibility.
    /// @param minBalance Minimum balance required. Use 0 to make the rule discount-only.
    /// @param discountBps Discount in basis points applied when the balance condition is met.
    /// @param minHoldTime Minimum time after recording an eligible balance before mint/renew can pass.
    struct Params {
        ERC20 token;
        uint256 minBalance;
        uint16 discountBps;
        uint64 minHoldTime;
    }

    mapping(bytes32 activationId => Params params) public params;
    mapping(bytes32 activationId => mapping(address account => uint64 observedAt)) public balanceObservedAt;

    event TokenBalanceRecorded(
        bytes32 indexed activationId, address indexed account, uint256 balance, uint64 observedAt
    );

    error InvalidTokenBalanceRule(bytes32 activationId);
    error InsufficientTokenBalance(bytes32 activationId, address account, address token, uint256 balance, uint256 min);
    error InvalidDiscountBps(uint16 discountBps);
    error InvalidTokenBalanceHoldTime(bytes32 activationId);
    error TokenBalanceHoldTimeNotMet(
        bytes32 activationId, address account, uint64 observedAt, uint64 minHoldTime, uint256 currentTime
    );

    /// @notice Store token balance parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (address(decoded.token) == address(0)) {
            revert InvalidTokenBalanceRule(activationId);
        }
        if (decoded.discountBps > 10_000) {
            revert InvalidDiscountBps(decoded.discountBps);
        }
        if (decoded.minBalance != 0 && decoded.minHoldTime == 0) {
            revert InvalidTokenBalanceHoldTime(activationId);
        }
        params[activationId] = decoded;
    }

    /// @notice Record the caller's current eligible balance before minting or renewing.
    function recordBalance(bytes32 activationId) external {
        Params memory stored = params[activationId];
        uint256 balance = _checkBalance(activationId, msg.sender, stored);
        uint64 observedAt = uint64(block.timestamp);
        balanceObservedAt[activationId][msg.sender] = observedAt;
        emit TokenBalanceRecorded(activationId, msg.sender, balance, observedAt);
    }

    /// @notice Evaluate rule.
    function evaluateMint(NamespaceTypes.MintContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        output = _evaluate(ctx.activationId, ctx.buyer);
    }

    /// @notice Evaluate rule.
    function evaluateRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        output = _evaluate(ctx.activationId, ctx.payer);
    }

    function _evaluate(bytes32 activationId, address account)
        private
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        Params memory stored = params[activationId];
        _checkBalance(activationId, account, stored);
        _checkHoldTime(activationId, account, stored);

        output.decision = NamespaceTypes.Decision.PASS;
        if (stored.discountBps != 0) {
            output.priceOp = NamespaceTypes.PriceOp.DISCOUNT_BPS;
            output.bps = stored.discountBps;
        }
    }

    function _checkBalance(bytes32 activationId, address account, Params memory stored)
        private
        view
        returns (uint256 balance)
    {
        balance = stored.token.balanceOf(account);
        if (balance < stored.minBalance) {
            revert InsufficientTokenBalance(activationId, account, address(stored.token), balance, stored.minBalance);
        }
    }

    function _checkHoldTime(bytes32 activationId, address account, Params memory stored) private view {
        uint64 minHoldTime = stored.minHoldTime;
        if (minHoldTime == 0) return;

        uint64 observedAt = balanceObservedAt[activationId][account];
        /// forge-lint: disable-next-line(block-timestamp)
        if (observedAt == 0 || block.timestamp < uint256(observedAt) + minHoldTime) {
            revert TokenBalanceHoldTimeNotMet(activationId, account, observedAt, minHoldTime, block.timestamp);
        }
    }
}
