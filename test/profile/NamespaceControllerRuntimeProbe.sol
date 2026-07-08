// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

import {IPaymentModule} from "src/interfaces/IPaymentModule.sol";
import {IPostHookModule} from "src/interfaces/IPostHookModule.sol";
import {NamespaceController} from "src/NamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";

contract NamespaceControllerRuntimeProbe is NamespaceController {
    struct RuntimeGasProfile {
        uint256 activationLoadAndActive;
        uint256 namespaceCurrent;
        uint256 ownerAdminCheck;
        uint256 durationAndRuntimeChecks;
        uint256 labelHashAndContext;
        uint256 labelActivationStore;
        uint256 labelStateAndActivationCheck;
        uint256 expiryAndContext;
        uint256 evaluateRules;
        uint256 registryWrite;
        uint256 collectPayment;
        uint256 postHooks;
        uint256 emitEvent;
        uint256 measuredBodyTotal;
    }

    function mintProfile(
        bytes32 activationId,
        string calldata label,
        uint64 duration,
        NamespaceTypes.RuntimeData calldata runtimeData
    ) external payable nonReentrant returns (uint256 tokenId, RuntimeGasProfile memory profile) {
        uint256 bodyStart = gasleft();
        uint256 sliceStart;
        if (duration == 0) revert ZeroDuration();

        sliceStart = gasleft();
        ActivationData storage activation = _requireActivation(activationId);
        if (!activation.active) revert ActivationNotActive(activationId);
        profile.activationLoadAndActive = sliceStart - gasleft();

        sliceStart = gasleft();
        _checkNamespaceCurrent(activationId, activation);
        profile.namespaceCurrent = sliceStart - gasleft();

        sliceStart = gasleft();
        _checkRegistryAdminAuthority(activation.owner, activation.registry);
        profile.ownerAdminCheck = sliceStart - gasleft();

        sliceStart = gasleft();
        _checkDuration(activationId, activation, duration);
        _checkRuntimeDataLengths(activation, runtimeData);
        profile.durationAndRuntimeChecks = sliceStart - gasleft();

        sliceStart = gasleft();
        uint256 labelId = uint256(keccak256(bytes(label)));
        bytes32 labelHash = bytes32(labelId);
        NamespaceTypes.MintContext memory ctx = _mintContext(activation, activationId, label, labelId, duration);
        profile.labelHashAndContext = sliceStart - gasleft();

        sliceStart = gasleft();
        labelActivations[address(activation.registry)][labelHash] = activationId;
        profile.labelActivationStore = sliceStart - gasleft();

        sliceStart = gasleft();
        NamespaceTypes.Price memory price = _evaluateMintRules(activation, ctx, runtimeData.ruleData);
        profile.evaluateRules = sliceStart - gasleft();

        sliceStart = gasleft();
        tokenId = activation.registry
            .register(
                label, msg.sender, IRegistry(address(0)), activation.resolver, activation.buyerRoleBitmap, ctx.expiry
            );
        profile.registryWrite = sliceStart - gasleft();

        sliceStart = gasleft();
        _collectMintProfile(activation, ctx, price, runtimeData.paymentData);
        profile.collectPayment = sliceStart - gasleft();

        sliceStart = gasleft();
        _runPostMintHooksProfile(activation, ctx, tokenId, runtimeData.postHookData);
        profile.postHooks = sliceStart - gasleft();

        sliceStart = gasleft();
        _emitMintProfile(activationId, label, tokenId, ctx, price);
        profile.emitEvent = sliceStart - gasleft();

        profile.measuredBodyTotal = bodyStart - gasleft();
    }

    function renewProfile(
        bytes32 activationId,
        string calldata label,
        uint64 duration,
        NamespaceTypes.RuntimeData calldata runtimeData
    ) external payable nonReentrant returns (uint64 newExpiry, RuntimeGasProfile memory profile) {
        uint256 bodyStart = gasleft();
        uint256 sliceStart;
        if (duration == 0) revert ZeroDuration();

        sliceStart = gasleft();
        ActivationData storage activation = _requireActivation(activationId);
        if (!activation.active) revert ActivationNotActive(activationId);
        profile.activationLoadAndActive = sliceStart - gasleft();

        sliceStart = gasleft();
        _checkNamespaceCurrent(activationId, activation);
        profile.namespaceCurrent = sliceStart - gasleft();

        sliceStart = gasleft();
        _checkRegistryAdminAuthority(activation.owner, activation.registry);
        profile.ownerAdminCheck = sliceStart - gasleft();

        sliceStart = gasleft();
        _checkDuration(activationId, activation, duration);
        _checkRuntimeDataLengths(activation, runtimeData);
        profile.durationAndRuntimeChecks = sliceStart - gasleft();

        NamespaceTypes.RenewContext memory ctx =
            _renewContextProfile(activation, activationId, label, duration, profile);
        newExpiry = ctx.newExpiry;

        sliceStart = gasleft();
        NamespaceTypes.Price memory price = _evaluateRenewRules(activation, ctx, runtimeData.ruleData);
        profile.evaluateRules = sliceStart - gasleft();

        sliceStart = gasleft();
        activation.registry.renew(ctx.tokenId, newExpiry);
        profile.registryWrite = sliceStart - gasleft();

        sliceStart = gasleft();
        _collectRenewProfile(activation, ctx, price, runtimeData.paymentData);
        profile.collectPayment = sliceStart - gasleft();

        sliceStart = gasleft();
        _runPostRenewHooksProfile(activation, ctx, runtimeData.postHookData);
        profile.postHooks = sliceStart - gasleft();

        sliceStart = gasleft();
        _emitRenewProfile(label, ctx, price);
        profile.emitEvent = sliceStart - gasleft();

        profile.measuredBodyTotal = bodyStart - gasleft();
    }

    function _collectMintProfile(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        NamespaceTypes.Price memory price,
        bytes calldata paymentData
    ) private {
        if (price.amount == 0 && msg.value == 0) return;
        _checkModule(activation.paymentModule, MODULE_KIND_PAYMENT);
        IPaymentModule(activation.paymentModule).collectMint{value: msg.value}(ctx, price, paymentData);
    }

    function _collectRenewProfile(
        ActivationData storage activation,
        NamespaceTypes.RenewContext memory ctx,
        NamespaceTypes.Price memory price,
        bytes calldata paymentData
    ) private {
        if (price.amount == 0 && msg.value == 0) return;
        _checkModule(activation.paymentModule, MODULE_KIND_PAYMENT);
        IPaymentModule(activation.paymentModule).collectRenew{value: msg.value}(ctx, price, paymentData);
    }

    function _renewContextProfile(
        ActivationData storage activation,
        bytes32 activationId,
        string calldata label,
        uint64 duration,
        RuntimeGasProfile memory profile
    ) private view returns (NamespaceTypes.RenewContext memory ctx) {
        uint256 sliceStart = gasleft();
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
        profile.labelStateAndActivationCheck = sliceStart - gasleft();

        sliceStart = gasleft();
        uint64 newExpiry = state.expiry + duration;
        ctx = NamespaceTypes.RenewContext({
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
        profile.expiryAndContext = sliceStart - gasleft();
    }

    function _runPostMintHooksProfile(
        ActivationData storage activation,
        NamespaceTypes.MintContext memory ctx,
        uint256 tokenId,
        bytes[] calldata postHookData
    ) private {
        uint256 length = activation.postHookCount;
        if (length == 0) return;
        if (length == 1) {
            address hook = activation.postHooks;
            _checkModule(hook, MODULE_KIND_POST_HOOK);
            IPostHookModule(hook).afterMint(ctx, tokenId, postHookData[0]);
            return;
        }
        bytes memory postHooks = _readModuleList(activation.postHooks, length);
        for (uint256 i; i < length;) {
            address hook = _moduleAt(postHooks, i);
            _checkModule(hook, MODULE_KIND_POST_HOOK);
            IPostHookModule(hook).afterMint(ctx, tokenId, postHookData[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _runPostRenewHooksProfile(
        ActivationData storage activation,
        NamespaceTypes.RenewContext memory ctx,
        bytes[] calldata postHookData
    ) private {
        uint256 length = activation.postHookCount;
        if (length == 0) return;
        if (length == 1) {
            address hook = activation.postHooks;
            _checkModule(hook, MODULE_KIND_POST_HOOK);
            IPostHookModule(hook).afterRenew(ctx, postHookData[0]);
            return;
        }
        bytes memory postHooks = _readModuleList(activation.postHooks, length);
        for (uint256 i; i < length;) {
            address hook = _moduleAt(postHooks, i);
            _checkModule(hook, MODULE_KIND_POST_HOOK);
            IPostHookModule(hook).afterRenew(ctx, postHookData[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _emitMintProfile(
        bytes32 activationId,
        string calldata label,
        uint256 tokenId,
        NamespaceTypes.MintContext memory ctx,
        NamespaceTypes.Price memory price
    ) private {
        emit SubnameMinted(activationId, ctx.labelHash, label, msg.sender, tokenId, price.token, price.amount);
    }

    function _emitRenewProfile(
        string calldata label,
        NamespaceTypes.RenewContext memory ctx,
        NamespaceTypes.Price memory price
    ) private {
        emit SubnameRenewed(
            ctx.activationId, ctx.labelHash, label, ctx.tokenId, ctx.newExpiry, price.token, price.amount
        );
    }
}
