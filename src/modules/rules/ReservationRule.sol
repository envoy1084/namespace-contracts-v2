// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceRule} from "src/modules/rules/NamespaceRule.sol";

/// @title ReservationRule
/// @notice Verifies reservation claims that can block, buyer-bind, and price labels.
contract ReservationRule is NamespaceRule {
    /// @notice Reservation rule params.
    /// @param root Merkle root of reservation claims. Use bytes32(0) to disable.
    struct Params {
        bytes32 root;
    }

    /// @notice Runtime reservation claim.
    /// @param labelHash Label covered by the claim.
    /// @param account Reserved account. Use address(0) for public/blocking claims.
    /// @param startTime Earliest timestamp where the claim is active. Use 0 to disable lower bound.
    /// @param endTime Timestamp where the claim stops applying. Use 0 for no upper bound.
    /// @param mintable Whether the proved label can be minted while the claim applies.
    /// @param token Payment token used by price effects.
    /// @param mintPrice Mint amount used by price effects.
    /// @param renewPrice Renewal amount used by price effects.
    /// @param priceOp Price operation. Use NONE for eligibility-only reservations.
    /// @param proof Merkle proof for the claim.
    struct Claim {
        bytes32 labelHash;
        address account;
        uint64 startTime;
        uint64 endTime;
        bool mintable;
        address token;
        uint128 mintPrice;
        uint128 renewPrice;
        NamespaceTypes.PriceOp priceOp;
        bytes32[] proof;
    }

    mapping(bytes32 activationId => bytes32 root) public roots;

    error MissingReservationClaim(bytes32 activationId, string label);
    error InvalidReservationClaim(bytes32 activationId, bytes32 labelHash, address account);
    error ReservationNotStarted(bytes32 activationId, bytes32 labelHash, uint64 startTime, uint256 currentTime);
    error ReservedLabelBlocked(bytes32 activationId, bytes32 labelHash);
    error ReservedForDifferentAccount(bytes32 activationId, bytes32 labelHash, address reservedFor, address buyer);
    error InvalidReservationPriceOp(NamespaceTypes.PriceOp priceOp);

    /// @notice Store reservation root for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        roots[activationId] = abi.decode(configData, (Params)).root;
    }

    /// @notice Evaluate rule.
    function evaluateMint(NamespaceTypes.MintContext calldata ctx, bytes calldata runtimeData)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        Claim memory claim = _loadClaim(ctx.activationId, ctx.label, ctx.labelHash, runtimeData);
        _checkClaim(ctx.activationId, claim, ctx.buyer);
        output = _priceOutput(claim, true);
    }

    /// @notice Evaluate rule.
    function evaluateRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata runtimeData)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        Claim memory claim = _loadClaim(ctx.activationId, ctx.label, ctx.labelHash, runtimeData);
        _checkClaim(ctx.activationId, claim, ctx.payer);
        output = _priceOutput(claim, false);
    }

    /// @notice Compute the double-hashed reservation leaf.
    function leaf(Claim memory claim) public pure returns (bytes32 result) {
        bytes32 inner;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, mload(claim))
            mstore(add(ptr, 0x20), mload(add(claim, 0x20)))
            mstore(add(ptr, 0x40), mload(add(claim, 0x40)))
            mstore(add(ptr, 0x60), mload(add(claim, 0x60)))
            mstore(add(ptr, 0x80), mload(add(claim, 0x80)))
            mstore(add(ptr, 0xa0), mload(add(claim, 0xa0)))
            mstore(add(ptr, 0xc0), mload(add(claim, 0xc0)))
            mstore(add(ptr, 0xe0), mload(add(claim, 0xe0)))
            mstore(add(ptr, 0x100), mload(add(claim, 0x100)))
            inner := keccak256(ptr, 0x120)
            mstore(ptr, inner)
            result := keccak256(ptr, 0x20)
        }
    }

    function _loadClaim(bytes32 activationId, string calldata label, bytes32 labelHash, bytes calldata runtimeData)
        private
        view
        returns (Claim memory claim)
    {
        bytes32 root = roots[activationId];
        if (root == bytes32(0)) {
            claim.mintable = true;
            return claim;
        }
        if (runtimeData.length == 0) {
            revert MissingReservationClaim(activationId, label);
        }

        claim = abi.decode(runtimeData, (Claim));
        if (claim.labelHash != labelHash || !_verifyProof(root, leaf(claim), claim.proof)) {
            revert InvalidReservationClaim(activationId, claim.labelHash, claim.account);
        }
    }

    function _checkClaim(bytes32 activationId, Claim memory claim, address account) private view {
        if (claim.labelHash == bytes32(0)) {
            return;
        }

        uint256 currentTime = block.timestamp;
        if (claim.startTime != 0 && currentTime < claim.startTime) {
            revert ReservationNotStarted(activationId, claim.labelHash, claim.startTime, currentTime);
        }
        if (claim.endTime != 0 && currentTime >= claim.endTime) {
            return;
        }
        if (!claim.mintable) {
            revert ReservedLabelBlocked(activationId, claim.labelHash);
        }
        if (claim.account != address(0) && claim.account != account) {
            revert ReservedForDifferentAccount(activationId, claim.labelHash, claim.account, account);
        }
    }

    function _priceOutput(Claim memory claim, bool mint)
        private
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        output.decision = NamespaceTypes.Decision.PASS;
        if (claim.labelHash == bytes32(0) || (claim.endTime != 0 && block.timestamp >= claim.endTime)) {
            return output;
        }

        NamespaceTypes.PriceOp priceOp = claim.priceOp;
        if (priceOp == NamespaceTypes.PriceOp.NONE) {
            return output;
        }
        if (priceOp != NamespaceTypes.PriceOp.ADD && priceOp != NamespaceTypes.PriceOp.OVERRIDE) {
            revert InvalidReservationPriceOp(priceOp);
        }
        output.priceOp = priceOp;
        output.token = claim.token;
        output.amount = mint ? claim.mintPrice : claim.renewPrice;
    }

    function _verifyProof(bytes32 root, bytes32 leaf_, bytes32[] memory proof) private pure returns (bool isValid) {
        uint256 length = proof.length;
        for (uint256 i; i < length;) {
            bytes32 proofElement = proof[i];
            assembly ("memory-safe") {
                let scratch := shl(5, gt(leaf_, proofElement))
                mstore(scratch, leaf_)
                mstore(xor(scratch, 0x20), proofElement)
                leaf_ := keccak256(0x00, 0x40)
            }
            unchecked {
                ++i;
            }
        }
        isValid = leaf_ == root;
    }
}
