// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

contract MockPermissionedRegistry {
    uint256 public constant ROLE_REGISTRAR = 1 << 0;
    uint256 public constant ROLE_RENEW = 1 << 16;

    struct NameRecord {
        address owner;
        IRegistry subregistry;
        address resolver;
        uint256 roleBitmap;
        uint64 expiry;
        uint256 tokenId;
    }

    mapping(address account => uint256 roles) public rootRoles;
    mapping(uint256 labelId => NameRecord record) public records;

    error MissingRootRole(address caller, uint256 role);
    error LabelNotAvailable(string label);
    error LabelExpired(uint256 labelId);
    error CannotReduceExpiry(uint64 oldExpiry, uint64 newExpiry);

    function grantRootRoles(uint256 roleBitmap, address account) external {
        rootRoles[account] |= roleBitmap;
    }

    function hasRootRoles(uint256 roleBitmap, address account) external view returns (bool) {
        return rootRoles[account] & roleBitmap == roleBitmap;
    }

    function getState(uint256 anyId) external view returns (IPermissionedRegistry.State memory state) {
        NameRecord memory record = records[_storageId(anyId)];
        state.expiry = record.expiry;
        state.tokenId = record.tokenId;
        state.resource = _storageId(anyId);
        state.latestOwner = record.owner;
        state.status = _status(record);
    }

    function register(
        string calldata label,
        address owner,
        IRegistry subregistry,
        address resolver,
        uint256 roleBitmap,
        uint64 expiry
    ) external returns (uint256 tokenId) {
        if (rootRoles[msg.sender] & ROLE_REGISTRAR != ROLE_REGISTRAR) {
            revert MissingRootRole(msg.sender, ROLE_REGISTRAR);
        }

        uint256 labelId = uint256(keccak256(bytes(label)));
        uint256 storageId = _storageId(labelId);
        NameRecord storage record = records[storageId];
        if (_status(record) != IPermissionedRegistry.Status.AVAILABLE) {
            revert LabelNotAvailable(label);
        }

        tokenId = labelId;
        record.owner = owner;
        record.subregistry = subregistry;
        record.resolver = resolver;
        record.roleBitmap = roleBitmap;
        record.expiry = expiry;
        record.tokenId = tokenId;
    }

    function renew(uint256 anyId, uint64 newExpiry) external {
        if (rootRoles[msg.sender] & ROLE_RENEW != ROLE_RENEW) {
            revert MissingRootRole(msg.sender, ROLE_RENEW);
        }

        NameRecord storage record = records[_storageId(anyId)];
        if (_status(record) == IPermissionedRegistry.Status.AVAILABLE) {
            revert LabelExpired(_storageId(anyId));
        }
        if (newExpiry < record.expiry) {
            revert CannotReduceExpiry(record.expiry, newExpiry);
        }
        record.expiry = newExpiry;
    }

    function ownerOf(uint256 anyId) external view returns (address) {
        return records[_storageId(anyId)].owner;
    }

    function resolverOf(uint256 anyId) external view returns (address) {
        return records[_storageId(anyId)].resolver;
    }

    function rolesOf(uint256 anyId) external view returns (uint256) {
        return records[_storageId(anyId)].roleBitmap;
    }

    function _status(NameRecord memory record) private view returns (IPermissionedRegistry.Status) {
        if (record.expiry == 0 || block.timestamp >= record.expiry) {
            return IPermissionedRegistry.Status.AVAILABLE;
        }
        if (record.owner == address(0)) {
            return IPermissionedRegistry.Status.RESERVED;
        }
        return IPermissionedRegistry.Status.REGISTERED;
    }

    function _storageId(uint256 anyId) private pure returns (uint256) {
        return anyId ^ uint32(anyId);
    }
}
