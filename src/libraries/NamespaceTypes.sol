// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistry} from "@ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

/// @title NamespaceTypes
/// @notice Shared structs used by the Namespace controller and modules.
/// @dev Keeping the types in one library prevents interface drift across modules.
library NamespaceTypes {
    /// @notice Module address and activation-time configuration payload.
    /// @param module Contract implementing one of the Namespace module interfaces.
    /// @param configData ABI-encoded module configuration for a specific activation.
    struct ModuleConfig {
        address module;
        bytes configData;
    }

    /// @notice Input used to create a namespace activation.
    /// @param registry ENSv2 registry where subnames are minted.
    /// @param parentNode Namehash of the parent name, e.g. alice.eth.
    /// @param resolver Default resolver assigned to minted subnames.
    /// @param buyerRoleBitmap ENSv2 registry roles granted to subname buyers.
    /// @param policies Stacked policy modules; every policy must pass.
    /// @param pricingModules Sequential pricing modules used to compose the final price.
    /// @param paymentModule Module that collects payment from the payer.
    /// @param processor Module that accounts for or distributes collected payment.
    /// @param postHooks Hooks called after the ENSv2 registry mint succeeds.
    struct ActivationConfig {
        IPermissionedRegistry registry;
        bytes32 parentNode;
        address resolver;
        uint256 buyerRoleBitmap;
        ModuleConfig[] policies;
        ModuleConfig[] pricingModules;
        ModuleConfig paymentModule;
        ModuleConfig processor;
        ModuleConfig[] postHooks;
    }

    /// @notice Public activation metadata used by the Namespace controller.
    /// @param owner Account that controls the activation.
    /// @param registry ENSv2 registry where labels are minted.
    /// @param parentNode Namehash of the parent name.
    /// @param resolver Default resolver assigned during mint.
    /// @param buyerRoleBitmap ENSv2 registry roles granted to minted-name owners.
    /// @param active Whether mints are currently enabled for this activation.
    /// @param paymentModule Active payment module.
    /// @param processor Active processor module.
    struct Activation {
        address owner;
        IPermissionedRegistry registry;
        bytes32 parentNode;
        address resolver;
        uint256 buyerRoleBitmap;
        bool active;
        address paymentModule;
        address processor;
    }

    /// @notice Runtime data supplied by a minter.
    /// @dev Data is split by module group so buyers only provide proof/input data,
    ///      not activation configuration.
    /// @param policyData Runtime data for each policy module.
    /// @param pricingData Runtime data for each pricing module.
    /// @param paymentData Runtime data for the payment module.
    /// @param processorData Runtime data for the processor module.
    /// @param postHookData Runtime data for each post-mint hook.
    struct RuntimeData {
        bytes[] policyData;
        bytes[] pricingData;
        bytes paymentData;
        bytes processorData;
        bytes[] postHookData;
    }

    /// @notice Shared context for a mint execution.
    /// @param activationId Unique id for the activation being used.
    /// @param buyer Account that will own the minted subname.
    /// @param payer Account paying for the mint. Initially equal to buyer.
    /// @param registry ENSv2 registry where the label is minted.
    /// @param parentNode Namehash of the parent name.
    /// @param label Direct child label being minted.
    /// @param labelHash Keccak hash of the direct child label.
    /// @param duration Requested registration duration.
    /// @param expiry Expiry timestamp written to the ENSv2 registry.
    /// @param resolver Resolver assigned to the minted subname.
    /// @param buyerRoleBitmap ENSv2 roles granted to the buyer.
    struct MintContext {
        bytes32 activationId;
        address buyer;
        address payer;
        IPermissionedRegistry registry;
        bytes32 parentNode;
        string label;
        bytes32 labelHash;
        uint64 duration;
        uint64 expiry;
        address resolver;
        uint256 buyerRoleBitmap;
    }

    /// @notice Shared context for a renewal execution.
    /// @param activationId Unique id for the activation being used.
    /// @param payer Account paying for renewal.
    /// @param registry ENSv2 registry where the label is stored.
    /// @param parentNode Namehash of the parent name.
    /// @param label Direct child label being renewed.
    /// @param labelHash Keccak hash of the direct child label.
    /// @param tokenId Current ENSv2 registry token id.
    /// @param duration Requested renewal extension.
    /// @param currentExpiry Current expiry before renewal.
    /// @param newExpiry Expiry timestamp after renewal.
    struct RenewContext {
        bytes32 activationId;
        address payer;
        IPermissionedRegistry registry;
        bytes32 parentNode;
        string label;
        bytes32 labelHash;
        uint256 tokenId;
        uint64 duration;
        uint64 currentExpiry;
        uint64 newExpiry;
    }

    /// @notice Payment quote composed by pricing modules.
    /// @param token Payment token address. Use address(0) for native ETH.
    /// @param amount Total amount required in `token`.
    struct Price {
        address token;
        uint256 amount;
    }
}
