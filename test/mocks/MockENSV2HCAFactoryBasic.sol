// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHCAFactoryBasic} from "@ensv2/hca/interfaces/IHCAFactoryBasic.sol";

contract MockENSV2HCAFactoryBasic is IHCAFactoryBasic {
    mapping(address hca => address owner) internal _ownerOf;

    function setAccountOwner(address hca, address owner) external {
        _ownerOf[hca] = owner;
    }

    function getAccountOwner(address hca) external view returns (address) {
        return _ownerOf[hca];
    }
}
