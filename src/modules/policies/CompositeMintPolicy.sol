// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";

import {IPolicyModule} from "src/interfaces/IPolicyModule.sol";
import {MerkleWhitelistPolicy} from "src/modules/policies/MerkleWhitelistPolicy.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title CompositeMintPolicy
/// @notice Gas-optimized policy bundle for common sale window, length, ERC20, reservation, and whitelist checks.
/// @dev Runtime data is `abi.encode(ReservationProofData, bytes32[] whitelistProof)`.
contract CompositeMintPolicy is NamespaceModule, IPolicyModule {
    struct Params {
        uint64 startTime;
        uint64 endTime;
        uint16 minLength;
        uint16 maxLength;
        ERC20 gateToken;
        uint256 minBalance;
        bytes32 reservationRoot;
        bytes32 whitelistMintRoot;
        bytes32 whitelistRenewRoot;
        MerkleWhitelistPolicy.LeafMode whitelistLeafMode;
    }

    struct ReservationProofData {
        address account;
        uint64 expiry;
        bytes32[] proof;
    }

    mapping(bytes32 activationId => Params params) public params;

    error InvalidCompositeSaleWindow(uint64 startTime, uint64 endTime);
    error InvalidCompositeLengthBounds(uint16 minLength, uint16 maxLength);
    error InvalidCompositeGate(bytes32 activationId);
    error CompositeSaleNotStarted(bytes32 activationId, uint64 startTime, uint256 currentTime);
    error CompositeSaleEnded(bytes32 activationId, uint64 endTime, uint256 currentTime);
    error CompositeLabelTooShort(bytes32 activationId, string label, uint256 length, uint16 minLength);
    error CompositeLabelTooLong(bytes32 activationId, string label, uint256 length, uint16 maxLength);
    error CompositeInsufficientERC20Balance(
        bytes32 activationId, address account, address token, uint256 balance, uint256 minBalance
    );
    error CompositeMissingReservationProof(bytes32 activationId, string label);
    error CompositeInvalidReservationProof(bytes32 activationId, bytes32 labelHash, address account, uint64 expiry);
    error CompositeReservedLabel(bytes32 activationId, string label, address reservedFor, uint64 expiry, address buyer);
    error CompositeInvalidWhitelistProof(bytes32 activationId, address account, bytes32 labelHash, bytes32 root);

    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (decoded.endTime != 0 && decoded.startTime > decoded.endTime) {
            revert InvalidCompositeSaleWindow(decoded.startTime, decoded.endTime);
        }
        if (decoded.maxLength != 0 && decoded.minLength > decoded.maxLength) {
            revert InvalidCompositeLengthBounds(decoded.minLength, decoded.maxLength);
        }
        if ((address(decoded.gateToken) == address(0)) != (decoded.minBalance == 0)) {
            revert InvalidCompositeGate(activationId);
        }
        params[activationId] = decoded;
    }

    function checkMint(NamespaceTypes.MintContext calldata ctx, bytes calldata runtimeData) external view {
        Params memory stored = params[ctx.activationId];
        _checkWindow(ctx.activationId, stored);
        _checkLength(ctx.activationId, ctx.label, stored);
        _checkBalance(ctx.activationId, ctx.buyer, stored);
        _checkReservation(ctx, stored.reservationRoot, runtimeData);
        _checkWhitelist(
            ctx.activationId,
            ctx.buyer,
            ctx.labelHash,
            stored.whitelistMintRoot,
            stored.whitelistLeafMode,
            _whitelistProofOffset(runtimeData)
        );
    }

    function checkRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata runtimeData) external view {
        Params memory stored = params[ctx.activationId];
        _checkWindow(ctx.activationId, stored);
        _checkLength(ctx.activationId, ctx.label, stored);
        _checkBalance(ctx.activationId, ctx.payer, stored);
        _checkWhitelist(
            ctx.activationId,
            ctx.payer,
            ctx.labelHash,
            stored.whitelistRenewRoot,
            stored.whitelistLeafMode,
            _renewWhitelistProofOffset(runtimeData)
        );
    }

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

    function _checkWindow(bytes32 activationId, Params memory stored) private view {
        uint256 currentTime = block.timestamp;
        if (stored.startTime != 0 && currentTime < stored.startTime) {
            revert CompositeSaleNotStarted(activationId, stored.startTime, currentTime);
        }
        if (stored.endTime != 0 && currentTime > stored.endTime) {
            revert CompositeSaleEnded(activationId, stored.endTime, currentTime);
        }
    }

    function _checkLength(bytes32 activationId, string calldata label, Params memory stored) private pure {
        uint256 length = bytes(label).length;
        if (length < stored.minLength) {
            revert CompositeLabelTooShort(activationId, label, length, stored.minLength);
        }
        if (stored.maxLength != 0 && length > stored.maxLength) {
            revert CompositeLabelTooLong(activationId, label, length, stored.maxLength);
        }
    }

    function _checkBalance(bytes32 activationId, address account, Params memory stored) private view {
        if (address(stored.gateToken) == address(0)) {
            return;
        }
        uint256 balance = stored.gateToken.balanceOf(account);
        if (balance < stored.minBalance) {
            revert CompositeInsufficientERC20Balance(
                activationId, account, address(stored.gateToken), balance, stored.minBalance
            );
        }
    }

    function _checkReservation(
        NamespaceTypes.MintContext calldata ctx,
        bytes32 root,
        bytes calldata runtimeData
    ) private view {
        if (root == bytes32(0)) {
            return;
        }
        if (runtimeData.length == 0) {
            revert CompositeMissingReservationProof(ctx.activationId, ctx.label);
        }

        (address account, uint64 expiry, uint256 proofOffset, uint256 proofLength, bool valid) =
            _decodeReservationProofData(runtimeData);
        bytes32 reservationLeaf = leaf(ctx.labelHash, account, expiry);
        if (!valid || !_verifyProofCalldata(root, reservationLeaf, proofOffset, proofLength)) {
            revert CompositeInvalidReservationProof(ctx.activationId, ctx.labelHash, account, expiry);
        }

        uint256 currentTime = block.timestamp;
        if (expiry != 0 && currentTime >= expiry) {
            return;
        }
        if (account != address(0) && account != ctx.buyer) {
            revert CompositeReservedLabel(ctx.activationId, ctx.label, account, expiry, ctx.buyer);
        }
    }

    function _checkWhitelist(
        bytes32 activationId,
        address account,
        bytes32 labelHash,
        bytes32 root,
        MerkleWhitelistPolicy.LeafMode leafMode,
        uint256 proofHeadOffset
    ) private pure {
        if (root == bytes32(0)) {
            return;
        }

        (uint256 proofOffset, uint256 proofLength, bool valid) = _decodeProofArray(proofHeadOffset);
        bytes32 whitelistLeaf = _whitelistLeaf(account, labelHash, leafMode);
        if (!valid || !_verifyProofCalldata(root, whitelistLeaf, proofOffset, proofLength)) {
            revert CompositeInvalidWhitelistProof(activationId, account, labelHash, root);
        }
    }

    function _decodeReservationProofData(bytes calldata runtimeData)
        private
        pure
        returns (address account, uint64 expiry, uint256 proofOffset, uint256 proofLength, bool valid)
    {
        assembly ("memory-safe") {
            let offset := runtimeData.offset
            let length := runtimeData.length
            if iszero(lt(length, 0xe0)) {
                let reservationRelativeOffset := calldataload(offset)
                let whitelistRelativeOffset := calldataload(add(offset, 0x20))
                if and(eq(reservationRelativeOffset, 0x40), gt(whitelistRelativeOffset, reservationRelativeOffset)) {
                    let tupleOffset := add(offset, reservationRelativeOffset)
                    let accountWord := calldataload(tupleOffset)
                    let expiryWord := calldataload(add(tupleOffset, 0x20))
                    let proofRelativeOffset := calldataload(add(tupleOffset, 0x40))
                    if and(eq(proofRelativeOffset, 0x60), and(iszero(shr(160, accountWord)), iszero(shr(64, expiryWord)))) {
                        proofLength := calldataload(add(tupleOffset, proofRelativeOffset))
                        let proofByteLength := shl(5, proofLength)
                        if eq(whitelistRelativeOffset, add(0xc0, proofByteLength)) {
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

    function _whitelistProofOffset(bytes calldata runtimeData) private pure returns (uint256 proofHeadOffset) {
        assembly ("memory-safe") {
            if iszero(lt(runtimeData.length, 0x40)) {
                proofHeadOffset := add(runtimeData.offset, calldataload(add(runtimeData.offset, 0x20)))
            }
        }
    }

    function _renewWhitelistProofOffset(bytes calldata runtimeData) private pure returns (uint256 proofHeadOffset) {
        assembly ("memory-safe") {
            if iszero(lt(runtimeData.length, 0x20)) {
                proofHeadOffset := add(runtimeData.offset, calldataload(runtimeData.offset))
            }
        }
    }

    function _decodeProofArray(uint256 proofHeadOffset)
        private
        pure
        returns (uint256 proofOffset, uint256 proofLength, bool valid)
    {
        assembly ("memory-safe") {
            if proofHeadOffset {
                proofLength := calldataload(proofHeadOffset)
                proofOffset := add(proofHeadOffset, 0x20)
                valid := 1
            }
        }
    }

    function _whitelistLeaf(address account, bytes32 labelHash, MerkleWhitelistPolicy.LeafMode leafMode)
        private
        pure
        returns (bytes32)
    {
        if (leafMode == MerkleWhitelistPolicy.LeafMode.ACCOUNT) {
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
