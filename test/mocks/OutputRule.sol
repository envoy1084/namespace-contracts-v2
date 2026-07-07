// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceRule} from "src/modules/rules/NamespaceRule.sol";

/// @notice Test-only rule that returns a configured output.
contract OutputRule is NamespaceRule {
    mapping(bytes32 activationId => NamespaceTypes.RuleOutput output) internal outputs;

    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        outputs[activationId] = abi.decode(configData, (NamespaceTypes.RuleOutput));
    }

    function evaluateMint(NamespaceTypes.MintContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        output = outputs[ctx.activationId];
    }

    function evaluateRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        output = outputs[ctx.activationId];
    }
}
