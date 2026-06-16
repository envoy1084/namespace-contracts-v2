// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPolicyModule} from "src/interfaces/IPolicyModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title ReservationPolicy
/// @notice Enforces activation-scoped reservations through Merkle proofs.
/// @dev Leaves are double hashes of ABI-encoded label hash, account, and expiry.
///      `account == address(0)` means any buyer may mint the proved label.
contract ReservationPolicy is NamespaceModule, IPolicyModule {
    /// @notice Activation configuration.
    /// @param reservationRoot Merkle root of `(labelHash, account, expiry)` leaves. Use bytes32(0) to disable.
    struct Params {
        bytes32 reservationRoot;
    }

    /// @notice Runtime reservation proof data.
    /// @param account Reserved account. Use address(0) for public mint with proof.
    /// @param expiry Timestamp after which a reserved account restriction expires. Use 0 for no expiry.
    /// @param proof Merkle proof for `(labelHash, account, expiry)`.
    struct ProofData {
        address account;
        uint64 expiry;
        bytes32[] proof;
    }

    mapping(bytes32 activationId => bytes32 reservationRoot) public reservationRoots;

    error MissingReservationProof(bytes32 activationId, string label);
    error InvalidReservationProof(bytes32 activationId, bytes32 labelHash, address account, uint64 expiry);
    error ReservedLabel(bytes32 activationId, string label, address reservedFor, uint64 expiry, address buyer);

    /// @notice Store the reservation Merkle root for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        reservationRoots[activationId] = decoded.reservationRoot;
    }

    /// @inheritdoc IPolicyModule
    function checkMint(NamespaceTypes.MintContext calldata ctx, bytes calldata runtimeData) external view {
        bytes32 root = reservationRoots[ctx.activationId];
        if (root == bytes32(0)) {
            return;
        }
        if (runtimeData.length == 0) {
            revert MissingReservationProof(ctx.activationId, ctx.label);
        }

        (address account, uint64 expiry, uint256 proofOffset, uint256 proofLength, bool valid) =
            _decodeProofData(runtimeData);
        bytes32 reservationLeaf = leaf(ctx.labelHash, account, expiry);
        if (!valid || !_verifyProofCalldata(root, reservationLeaf, proofOffset, proofLength)) {
            revert InvalidReservationProof(ctx.activationId, ctx.labelHash, account, expiry);
        }

        uint256 currentTime = block.timestamp;
        if (expiry != 0 && currentTime >= expiry) {
            return;
        }
        if (account != address(0) && account != ctx.buyer) {
            revert ReservedLabel(ctx.activationId, ctx.label, account, expiry, ctx.buyer);
        }
    }

    /// @inheritdoc IPolicyModule
    function checkRenew(NamespaceTypes.RenewContext calldata, bytes calldata) external pure {}

    /// @notice Compute the double-hashed reservation leaf used by Solady Merkle verification.
    function leaf(bytes32 labelHash, address account, uint64 expiry) public pure returns (bytes32 result) {
        bytes32 inner;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, labelHash)
            mstore(add(ptr, 0x20), account)
            mstore(add(ptr, 0x40), expiry)
            inner := keccak256(ptr, 0x60)
            mstore(ptr, inner)
            result := keccak256(ptr, 0x20)
        }
    }

    function _decodeProofData(bytes calldata runtimeData)
        private
        pure
        returns (address account, uint64 expiry, uint256 proofOffset, uint256 proofLength, bool valid)
    {
        assembly ("memory-safe") {
            let offset := runtimeData.offset
            let length := runtimeData.length
            if iszero(lt(length, 0xa0)) {
                let tupleRelativeOffset := calldataload(offset)
                if eq(tupleRelativeOffset, 0x20) {
                    let tupleOffset := add(offset, tupleRelativeOffset)
                    let accountWord := calldataload(tupleOffset)
                    let expiryWord := calldataload(add(tupleOffset, 0x20))
                    let proofRelativeOffset := calldataload(add(tupleOffset, 0x40))
                    if and(eq(proofRelativeOffset, 0x60), iszero(shr(160, accountWord))) {
                        if iszero(shr(64, expiryWord)) {
                            proofLength := calldataload(add(tupleOffset, proofRelativeOffset))
                            let proofByteLength := shl(5, proofLength)
                            if eq(length, add(0xa0, proofByteLength)) {
                                valid := 1
                                account := accountWord
                                expiry := expiryWord
                                proofOffset := add(add(tupleOffset, proofRelativeOffset), 0x20)
                            }
                        }
                    }
                }
            }
        }
    }

    function _verifyProofCalldata(bytes32 root, bytes32 leaf_, uint256 proofOffset, uint256 proofLength)
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
                    let scratch := shl(5, gt(leaf_, proofElement))
                    mstore(scratch, leaf_)
                    mstore(xor(scratch, 0x20), proofElement)
                    leaf_ := keccak256(0x00, 0x40)
                    offset := add(offset, 0x20)
                    if iszero(lt(offset, end)) { break }
                }
            }
            isValid := eq(leaf_, root)
        }
    }
}
