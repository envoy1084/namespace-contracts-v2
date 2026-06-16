// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPostHookModule} from "src/interfaces/IPostHookModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

contract RecordingPostHook is NamespaceModule, IPostHookModule {
    bytes32 public lastActivationId;
    address public lastBuyer;
    bytes32 public lastLabelHash;
    uint256 public lastTokenId;
    bytes public lastRuntimeData;
    uint64 public lastNewExpiry;

    function configure(bytes32, bytes calldata) external view onlyController {}

    function afterMint(NamespaceTypes.MintContext calldata ctx, uint256 tokenId, bytes calldata runtimeData)
        external
        onlyController
    {
        lastActivationId = ctx.activationId;
        lastBuyer = ctx.buyer;
        lastLabelHash = ctx.labelHash;
        lastTokenId = tokenId;
        lastRuntimeData = runtimeData;
    }

    function afterRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata runtimeData) external onlyController {
        lastActivationId = ctx.activationId;
        lastLabelHash = ctx.labelHash;
        lastTokenId = ctx.tokenId;
        lastNewExpiry = ctx.newExpiry;
        lastRuntimeData = runtimeData;
    }
}
