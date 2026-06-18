// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceRule} from "src/modules/rules/NamespaceRule.sol";

/// @title WhitelistRule
/// @notice Verifies whitelist claims that can allow, block, discount, or price labels.
contract WhitelistRule is NamespaceRule {
    /// @notice Whitelist rule params.
    /// @param mintRoot Merkle root used for mints. Use bytes32(0) to disable mint checks.
    /// @param renewRoot Merkle root used for renewals. Use bytes32(0) to disable renewal checks.
    struct Params {
        bytes32 mintRoot;
        bytes32 renewRoot;
    }

    /// @notice Runtime whitelist claim.
    /// @param labelHash Optional label covered by the claim. Use bytes32(0) for any label.
    /// @param account Optional account covered by the claim. Use address(0) for any buyer.
    /// @param startTime Earliest timestamp where the claim is active. Use 0 to disable lower bound.
    /// @param endTime Timestamp where the claim stops applying. Use 0 for no upper bound.
    /// @param mintable Whether the proved claim allows minting/renewal while active.
    /// @param token Payment token used by absolute price effects.
    /// @param mintPrice Mint amount used by price effects.
    /// @param renewPrice Renewal amount used by price effects.
    /// @param discountBps Discount applied when non-zero.
    /// @param priceOp Price operation. Use NONE for eligibility-only whitelist entries.
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
        uint16 discountBps;
        NamespaceTypes.PriceOp priceOp;
        bytes32[] proof;
    }

    mapping(bytes32 activationId => Params params) public params;

    error MissingWhitelistClaim(bytes32 activationId, bytes32 root);
    error InvalidWhitelistClaim(bytes32 activationId, bytes32 labelHash, address account);
    error WhitelistNotStarted(bytes32 activationId, uint64 startTime, uint256 currentTime);
    error WhitelistClaimExpired(bytes32 activationId, uint64 endTime, uint256 currentTime);
    error WhitelistClaimBlocked(bytes32 activationId, bytes32 labelHash, address account);
    error WhitelistAccountMismatch(bytes32 activationId, address expected, address actual);
    error WhitelistLabelMismatch(bytes32 activationId, bytes32 expected, bytes32 actual);
    error InvalidWhitelistPriceOp(NamespaceTypes.PriceOp priceOp);
    error InvalidWhitelistDiscount(uint16 discountBps);

    /// @notice Store whitelist roots for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        params[activationId] = abi.decode(configData, (Params));
    }

    /// @notice Evaluate rule.
    function evaluateMint(NamespaceTypes.MintContext calldata ctx, bytes calldata runtimeData)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        Claim memory claim = _loadClaim(ctx.activationId, params[ctx.activationId].mintRoot, runtimeData);
        _checkClaim(ctx.activationId, claim, ctx.buyer, ctx.labelHash);
        output = _priceOutput(claim, true);
    }

    /// @notice Evaluate rule.
    function evaluateRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata runtimeData)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        Claim memory claim = _loadClaim(ctx.activationId, params[ctx.activationId].renewRoot, runtimeData);
        _checkClaim(ctx.activationId, claim, ctx.payer, ctx.labelHash);
        output = _priceOutput(claim, false);
    }

    /// @notice Compute the double-hashed whitelist leaf.
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
            mstore(add(ptr, 0x120), mload(add(claim, 0x120)))
            inner := keccak256(ptr, 0x140)
            mstore(ptr, inner)
            result := keccak256(ptr, 0x20)
        }
    }

    function _loadClaim(bytes32 activationId, bytes32 root, bytes calldata runtimeData)
        private
        pure
        returns (Claim memory claim)
    {
        if (root == bytes32(0)) {
            claim.mintable = true;
            return claim;
        }
        if (runtimeData.length == 0) {
            revert MissingWhitelistClaim(activationId, root);
        }

        claim = abi.decode(runtimeData, (Claim));
        if (!_verifyProof(root, leaf(claim), claim.proof)) {
            revert InvalidWhitelistClaim(activationId, claim.labelHash, claim.account);
        }
    }

    function _checkClaim(bytes32 activationId, Claim memory claim, address account, bytes32 labelHash) private view {
        uint256 currentTime = block.timestamp;
        if (claim.startTime != 0 && currentTime < claim.startTime) {
            revert WhitelistNotStarted(activationId, claim.startTime, currentTime);
        }
        if (claim.endTime != 0 && currentTime >= claim.endTime) {
            revert WhitelistClaimExpired(activationId, claim.endTime, currentTime);
        }
        if (!claim.mintable) {
            revert WhitelistClaimBlocked(activationId, claim.labelHash, claim.account);
        }
        if (claim.account != address(0) && claim.account != account) {
            revert WhitelistAccountMismatch(activationId, claim.account, account);
        }
        if (claim.labelHash != bytes32(0) && claim.labelHash != labelHash) {
            revert WhitelistLabelMismatch(activationId, claim.labelHash, labelHash);
        }
    }

    function _priceOutput(Claim memory claim, bool mint)
        private
        pure
        returns (NamespaceTypes.RuleOutput memory output)
    {
        output.decision = NamespaceTypes.Decision.PASS;
        if (claim.discountBps != 0) {
            if (claim.discountBps > 10_000) {
                revert InvalidWhitelistDiscount(claim.discountBps);
            }
            output.priceOp = NamespaceTypes.PriceOp.DISCOUNT_BPS;
            output.bps = claim.discountBps;
            return output;
        }

        NamespaceTypes.PriceOp priceOp = claim.priceOp;
        if (priceOp == NamespaceTypes.PriceOp.NONE) {
            return output;
        }
        if (priceOp != NamespaceTypes.PriceOp.ADD && priceOp != NamespaceTypes.PriceOp.OVERRIDE) {
            revert InvalidWhitelistPriceOp(priceOp);
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
