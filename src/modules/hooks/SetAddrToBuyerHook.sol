// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAddrResolver} from "src/interfaces/IAddrResolver.sol";
import {IPostHookModule} from "src/interfaces/IPostHookModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title SetAddrToBuyerHook
/// @notice Sets `addr(node)` on the configured resolver after a successful mint.
/// @dev Runtime data may optionally ABI-encode an address override. If omitted, the buyer is used.
contract SetAddrToBuyerHook is NamespaceModule, IPostHookModule {
    error ResolverNotConfigured(bytes32 activationId);
    error InvalidRuntimeDataLength(uint256 length);

    constructor(address controller_) NamespaceModule(controller_) {}

    /// @notice Accept activation configuration without storing hook state.
    function configure(bytes32, bytes calldata) external view onlyController {
        // Intentionally no-op.
    }

    /// @inheritdoc IPostHookModule
    function afterMint(NamespaceTypes.MintContext calldata ctx, uint256, bytes calldata runtimeData)
        external
        onlyController
    {
        if (ctx.resolver == address(0)) {
            revert ResolverNotConfigured(ctx.activationId);
        }

        address addr_ = ctx.buyer;
        if (runtimeData.length != 0) {
            if (runtimeData.length != 32) {
                revert InvalidRuntimeDataLength(runtimeData.length);
            }
            addr_ = abi.decode(runtimeData, (address));
        }

        IAddrResolver(ctx.resolver).setAddr(_childNode(ctx.parentNode, ctx.labelHash), addr_);
    }

    /// @inheritdoc IPostHookModule
    function afterRenew(NamespaceTypes.RenewContext calldata, bytes calldata) external view onlyController {
        // Intentionally no-op.
    }

    function _childNode(bytes32 parentNode, bytes32 labelHash) private pure returns (bytes32) {
        // Keep the straightforward ENS namehash-style composition for readability.
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encodePacked(parentNode, labelHash));
    }
}
