// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {NamespaceController} from "src/NamespaceController.sol";

contract Deploy is Script {
    function run() public {
        address owner = vm.envOr("NAMESPACE_OWNER", msg.sender);

        vm.startBroadcast();

        NamespaceController controller = new NamespaceController(owner);
        console.log("NamespaceController deployed to:", address(controller));
        console.log("NamespaceController owner:", owner);

        vm.stopBroadcast();
    }
}
