// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {IPolicyModule} from "src/interfaces/IPolicyModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title ReservationPolicy
/// @notice Enforces activation-scoped reservations through Merkle proofs.
/// @dev Leaves are OpenZeppelin-style double hashes of ABI-encoded label hash, account, and expiry.
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

    constructor(address controller_) NamespaceModule(controller_) {}

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

        ProofData memory proofData = abi.decode(runtimeData, (ProofData));
        bytes32 reservationLeaf = leaf(ctx.labelHash, proofData.account, proofData.expiry);
        if (!MerkleProof.verify(proofData.proof, root, reservationLeaf)) {
            revert InvalidReservationProof(ctx.activationId, ctx.labelHash, proofData.account, proofData.expiry);
        }

        uint256 currentTime = block.timestamp;
        if (proofData.expiry != 0 && currentTime >= proofData.expiry) {
            return;
        }
        if (proofData.account != address(0) && proofData.account != ctx.buyer) {
            revert ReservedLabel(ctx.activationId, ctx.label, proofData.account, proofData.expiry, ctx.buyer);
        }
    }

    /// @inheritdoc IPolicyModule
    function checkRenew(NamespaceTypes.RenewContext calldata, bytes calldata) external pure {}

    /// @notice Compute an OpenZeppelin-compatible double-hashed reservation leaf.
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
}
