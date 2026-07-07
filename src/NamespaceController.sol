// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

import {IPaymentModule} from "src/interfaces/IPaymentModule.sol";
import {IPostHookModule} from "src/interfaces/IPostHookModule.sol";
import {INamespaceController} from "src/interfaces/INamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceControllerRules} from "src/controller/NamespaceControllerRules.sol";

/// @title NamespaceController
/// @notice Activation-based controller for minting ENSv2 subnames through official registries.
/// @dev Thin execution entry point; storage, activation lifecycle, module lists, and rule engine
///      live in inherited abstract contracts for easier audit review.
contract NamespaceController is NamespaceControllerRules {
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc INamespaceController
    function mint(
        bytes32 activationId,
        string calldata label,
        uint64 duration,
        NamespaceTypes.RuntimeData calldata runtimeData
    ) external payable nonReentrant returns (uint256 tokenId) {
        if (duration == 0) revert ZeroDuration();

        ActivationData storage activation = _requireActivation(activationId);
        if (!activation.active) revert ActivationNotActive(activationId);
        _checkRegistryAdminAuthority(activation.owner, activation.registry);
        _checkRuntimeDataLengths(activation, runtimeData);

        uint256 labelId = uint256(keccak256(bytes(label)));
        NamespaceTypes.MintContext memory ctx = _mintContext(activation, activationId, label, labelId, duration);
        NamespaceTypes.Price memory price = _evaluateMintRules(activation, ctx, runtimeData.ruleData);

        tokenId = activation.registry
            .register(
                label, msg.sender, IRegistry(address(0)), activation.resolver, activation.buyerRoleBitmap, ctx.expiry
            );
        labelActivations[address(activation.registry)][bytes32(labelId)] = activationId;

        _collectMint(activation, ctx, price, runtimeData.paymentData);
        _runPostMintHooks(activation, ctx, tokenId, runtimeData.postHookData);

        emit SubnameMinted(activationId, bytes32(labelId), label, msg.sender, tokenId, price.token, price.amount);
    }

    /// @inheritdoc INamespaceController
    function renew(
        bytes32 activationId,
        string calldata label,
        uint64 duration,
        NamespaceTypes.RuntimeData calldata runtimeData
    ) external payable nonReentrant returns (uint64 newExpiry) {
        if (duration == 0) revert ZeroDuration();

        ActivationData storage activation = _requireActivation(activationId);
        if (!activation.active) revert ActivationNotActive(activationId);
        _checkRegistryAdminAuthority(activation.owner, activation.registry);
        _checkRuntimeDataLengths(activation, runtimeData);

        uint256 labelId = uint256(keccak256(bytes(label)));
        IPermissionedRegistry.State memory state = activation.registry.getState(labelId);
        if (state.status != IPermissionedRegistry.Status.REGISTERED) {
            revert LabelNotRenewable(label, state.status);
        }
        bytes32 labelHash = bytes32(labelId);
        bytes32 labelActivationId = labelActivations[address(activation.registry)][labelHash];
        if (labelActivationId != activationId) {
            revert LabelActivationMismatch(label, activationId, labelActivationId);
        }

        newExpiry = state.expiry + duration;
        NamespaceTypes.RenewContext memory ctx = NamespaceTypes.RenewContext({
            activationId: activationId,
            payer: msg.sender,
            registry: activation.registry,
            parentNode: activation.parentNode,
            label: label,
            labelHash: labelHash,
            tokenId: state.tokenId,
            duration: duration,
            currentExpiry: state.expiry,
            newExpiry: newExpiry
        });

        NamespaceTypes.Price memory price = _evaluateRenewRules(activation, ctx, runtimeData.ruleData);

        activation.registry.renew(state.tokenId, newExpiry);
        _collectRenew(activation, ctx, price, runtimeData.paymentData);
        _runPostRenewHooks(activation, ctx, runtimeData.postHookData);

        emit SubnameRenewed(activationId, bytes32(labelId), label, state.tokenId, newExpiry, price.token, price.amount);
    }

    function _collectMint(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        NamespaceTypes.Price memory price,
        bytes calldata paymentData
    ) private {
        if (price.amount == 0 && msg.value == 0) return;
        if (activation.paymentModule == address(0)) revert ZeroModule(MODULE_KIND_PAYMENT);
        IPaymentModule(activation.paymentModule).collectMint{value: msg.value}(ctx, price, paymentData);
    }

    function _collectRenew(
        ActivationData storage activation,
        NamespaceTypes.RenewContext memory ctx,
        NamespaceTypes.Price memory price,
        bytes calldata paymentData
    ) private {
        if (price.amount == 0 && msg.value == 0) return;
        if (activation.paymentModule == address(0)) revert ZeroModule(MODULE_KIND_PAYMENT);
        IPaymentModule(activation.paymentModule).collectRenew{value: msg.value}(ctx, price, paymentData);
    }

    function _runPostMintHooks(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        uint256 tokenId,
        bytes[] calldata postHookData
    ) private {
        uint256 length = activation.postHookCount;
        if (length == 0) return;
        if (length == 1) {
            IPostHookModule(activation.postHooks).afterMint(ctx, tokenId, postHookData[0]);
            return;
        }
        bytes memory postHooks = _readModuleList(activation.postHooks, length);
        for (uint256 i; i < length;) {
            IPostHookModule(_moduleAt(postHooks, i)).afterMint(ctx, tokenId, postHookData[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _runPostRenewHooks(
        ActivationData storage activation,
        NamespaceTypes.RenewContext memory ctx,
        bytes[] calldata postHookData
    ) private {
        uint256 length = activation.postHookCount;
        if (length == 0) return;
        if (length == 1) {
            IPostHookModule(activation.postHooks).afterRenew(ctx, postHookData[0]);
            return;
        }
        bytes memory postHooks = _readModuleList(activation.postHooks, length);
        for (uint256 i; i < length;) {
            IPostHookModule(_moduleAt(postHooks, i)).afterRenew(ctx, postHookData[i]);
            unchecked {
                ++i;
            }
        }
    }
}
