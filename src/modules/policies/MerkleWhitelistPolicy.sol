// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPolicyModule} from "src/interfaces/IPolicyModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title MerkleWhitelistPolicy
/// @notice Enforces activation-scoped allowlists with per-call Merkle proofs.
/// @dev Leaves are double-hashed before Solady Merkle proof verification.
contract MerkleWhitelistPolicy is NamespaceModule, IPolicyModule {
    /// @notice Leaf shape used by the activation.
    /// @dev ACCOUNT gates only the wallet. ACCOUNT_LABEL gates the wallet and exact label.
    enum LeafMode {
        ACCOUNT,
        ACCOUNT_LABEL
    }

    /// @notice Activation configuration.
    /// @param mintRoot Merkle root used for mints. Use bytes32(0) to disable mint whitelist checks.
    /// @param renewRoot Merkle root used for renewals. Use bytes32(0) to disable renewal whitelist checks.
    /// @param leafMode Leaf encoding mode used for both roots.
    struct Params {
        bytes32 mintRoot;
        bytes32 renewRoot;
        LeafMode leafMode;
    }

    mapping(bytes32 activationId => Params params) public params;

    error InvalidWhitelistProof(bytes32 activationId, address account, bytes32 labelHash, bytes32 root);

    /// @notice Store whitelist roots for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        params[activationId] = abi.decode(configData, (Params));
    }

    /// @inheritdoc IPolicyModule
    function checkMint(NamespaceTypes.MintContext calldata ctx, bytes calldata runtimeData) external view {
        Params memory stored = params[ctx.activationId];
        _checkProof(ctx.activationId, ctx.buyer, ctx.labelHash, stored.mintRoot, stored.leafMode, runtimeData);
    }

    /// @inheritdoc IPolicyModule
    function checkRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata runtimeData) external view {
        Params memory stored = params[ctx.activationId];
        _checkProof(ctx.activationId, ctx.payer, ctx.labelHash, stored.renewRoot, stored.leafMode, runtimeData);
    }

    function _checkProof(
        bytes32 activationId,
        address account,
        bytes32 labelHash,
        bytes32 root,
        LeafMode leafMode,
        bytes calldata runtimeData
    ) private pure {
        if (root == bytes32(0)) {
            return;
        }

        (uint256 proofOffset, uint256 proofLength, bool valid) = _decodeProof(runtimeData);
        bytes32 leaf = _leaf(account, labelHash, leafMode);
        if (!valid || !_verifyProofCalldata(root, leaf, proofOffset, proofLength)) {
            revert InvalidWhitelistProof(activationId, account, labelHash, root);
        }
    }

    function _leaf(address account, bytes32 labelHash, LeafMode leafMode) private pure returns (bytes32) {
        if (leafMode == LeafMode.ACCOUNT) {
            return _hashAccount(account);
        }
        return _hashAccountLabel(account, labelHash);
    }

    function _hashAccount(address account) private pure returns (bytes32 result) {
        bytes32 inner;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, account)
            inner := keccak256(ptr, 0x20)
            mstore(ptr, inner)
            result := keccak256(ptr, 0x20)
        }
    }

    function _hashAccountLabel(address account, bytes32 labelHash) private pure returns (bytes32 result) {
        bytes32 inner;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, account)
            mstore(add(ptr, 0x20), labelHash)
            inner := keccak256(ptr, 0x40)
            mstore(ptr, inner)
            result := keccak256(ptr, 0x20)
        }
    }

    function _decodeProof(bytes calldata runtimeData)
        private
        pure
        returns (uint256 proofOffset, uint256 proofLength, bool valid)
    {
        assembly ("memory-safe") {
            let offset := runtimeData.offset
            let length := runtimeData.length
            if iszero(lt(length, 0x40)) {
                let proofRelativeOffset := calldataload(offset)
                if eq(proofRelativeOffset, 0x20) {
                    proofLength := calldataload(add(offset, 0x20))
                    let proofByteLength := shl(5, proofLength)
                    if eq(length, add(0x40, proofByteLength)) {
                        valid := 1
                        proofOffset := add(offset, 0x40)
                    }
                }
            }
        }
    }

    function _verifyProofCalldata(bytes32 root, bytes32 leaf, uint256 proofOffset, uint256 proofLength)
        private
        pure
        returns (bool isValid)
    {
        assembly ("memory-safe") {
            if proofLength {
                let offset := proofOffset
                let end := add(offset, shl(5, proofLength))
                for {} 1 {} {
                    let proofElement := calldataload(offset)
                    let scratch := shl(5, gt(leaf, proofElement))
                    mstore(scratch, leaf)
                    mstore(xor(scratch, 0x20), proofElement)
                    leaf := keccak256(0x00, 0x40)
                    offset := add(offset, 0x20)
                    if iszero(lt(offset, end)) { break }
                }
            }
            isValid := eq(leaf, root)
        }
    }
}
