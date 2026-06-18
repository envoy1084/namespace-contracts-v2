// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRuleModule} from "src/interfaces/IRuleModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title NamespaceRule
/// @notice Base contract for Namespace rule modules.
abstract contract NamespaceRule is NamespaceModule, IRuleModule {
    function _pass() internal pure returns (NamespaceTypes.RuleOutput memory output) {
        output.decision = NamespaceTypes.Decision.PASS;
    }
}
