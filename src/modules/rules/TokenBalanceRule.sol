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
    struct Params {
        ERC20 token;
        uint256 minBalance;
        uint16 discountBps;
    }

    mapping(bytes32 activationId => Params params) public params;

    error InvalidTokenBalanceRule(bytes32 activationId);
    error InsufficientTokenBalance(bytes32 activationId, address account, address token, uint256 balance, uint256 min);
    error InvalidDiscountBps(uint16 discountBps);

    /// @notice Store token balance parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (address(decoded.token) == address(0)) {
            revert InvalidTokenBalanceRule(activationId);
        }
        if (decoded.discountBps > 10_000) {
            revert InvalidDiscountBps(decoded.discountBps);
        }
        params[activationId] = decoded;
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
        uint256 balance = stored.token.balanceOf(account);
        if (balance < stored.minBalance) {
            revert InsufficientTokenBalance(activationId, account, address(stored.token), balance, stored.minBalance);
        }

        output.decision = NamespaceTypes.Decision.PASS;
        if (stored.discountBps != 0) {
            output.priceOp = NamespaceTypes.PriceOp.DISCOUNT_BPS;
            output.bps = stored.discountBps;
        }
    }
}
