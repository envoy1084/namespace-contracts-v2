// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";

contract ParentChainRegistry is IRegistry {
    IRegistry internal parent_;
    string internal label_;
    mapping(bytes32 labelHash => IRegistry registry) internal subregistries;

    function setParent(IRegistry parent, string memory label) external {
        parent_ = parent;
        label_ = label;
    }

    function setSubregistry(string memory label, IRegistry registry) external {
        subregistries[keccak256(bytes(label))] = registry;
    }

    function getSubregistry(string calldata label) external view returns (IRegistry) {
        return subregistries[keccak256(bytes(label))];
    }

    function getResolver(string calldata) external pure returns (address) {
        return address(0);
    }

    function getParent() external view returns (IRegistry parent, string memory label) {
        return (parent_, label_);
    }
}
