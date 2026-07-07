// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {EfficientHashLib} from "solady/utils/EfficientHashLib.sol";

import {IAddrResolver} from "src/interfaces/IAddrResolver.sol";
import {IPostHookModule} from "src/interfaces/IPostHookModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title BatchSetAddrToBuyerHook
/// @notice Sets one or more resolver `addr(node)` records after a successful mint.
/// @dev Runtime data is a tightly packed list of 20-byte address overrides. A zero override uses the buyer.
///      Empty runtime data writes the buyer address once.
contract BatchSetAddrToBuyerHook is NamespaceModule, IPostHookModule {
    error ResolverNotConfigured(bytes32 activationId);
    error InvalidRuntimeDataLength(uint256 length);

    /// @notice Accept activation configuration without storing hook state.
    function configure(bytes32, bytes calldata) external view onlyController {
        // Intentionally no-op.
    }

    /// @inheritdoc IPostHookModule
    function afterMint(NamespaceTypes.MintContext calldata ctx, uint256, bytes calldata runtimeData)
        external
        onlyController
    {
        address resolver = ctx.resolver;
        if (resolver == address(0)) {
            revert ResolverNotConfigured(ctx.activationId);
        }

        bytes32 node = EfficientHashLib.hash(ctx.parentNode, ctx.labelHash);
        address buyer = ctx.buyer;
        uint256 length = runtimeData.length;
        if (length == 0) {
            IAddrResolver(resolver).setAddr(node, buyer);
            return;
        }
        if (length % 20 != 0) {
            revert InvalidRuntimeDataLength(length);
        }

        IAddrResolver addrResolver = IAddrResolver(resolver);
        for (uint256 offset; offset < length;) {
            address addr_;
            assembly ("memory-safe") {
                addr_ := shr(96, calldataload(add(runtimeData.offset, offset)))
            }
            if (addr_ == address(0)) {
                addr_ = buyer;
            }
            addrResolver.setAddr(node, addr_);
            unchecked {
                offset += 20;
            }
        }
    }

    /// @inheritdoc IPostHookModule
    function afterRenew(NamespaceTypes.RenewContext calldata, bytes calldata) external view onlyController {
        // Intentionally no-op.
    }
}
