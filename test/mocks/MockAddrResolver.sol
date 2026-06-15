// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAddrResolver} from "src/interfaces/IAddrResolver.sol";

contract MockAddrResolver is IAddrResolver {
    mapping(bytes32 node => address addr) public addrs;

    function setAddr(bytes32 node, address addr_) external {
        addrs[node] = addr_;
    }
}
