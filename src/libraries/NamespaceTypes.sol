// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

/// @title NamespaceTypes
/// @notice Shared structs used by the Namespace controller and modules.
/// @dev Keeping the types in one library prevents interface drift across modules.
library NamespaceTypes {
    /// @notice Operation being evaluated by a rule.
    enum Operation {
        MINT,
        RENEW
    }

    /// @notice Deterministic phase used to order rule effects.
    enum RulePhase {
        GUARD,
        ELIGIBILITY,
        BASE_PRICE,
        PREMIUM,
        DISCOUNT,
        OVERRIDE,
        FINAL_CHECK
    }

    /// @notice Rule-level execution decision.
    enum Decision {
        PASS,
        BLOCK,
        SKIP
    }

    /// @notice Price transformation emitted by a rule.
    enum PriceOp {
        NONE,
        SET_BASE,
        ADD,
        SUBTRACT,
        DISCOUNT_BPS,
        MARKUP_BPS,
        MIN,
        MAX,
        OVERRIDE
    }

    /// @notice Module address and activation-time configuration payload.
    /// @param module Contract implementing one of the Namespace module interfaces.
    /// @param configData ABI-encoded module configuration for a specific activation.
    struct ModuleConfig {
        address module;
        bytes configData;
    }

    /// @notice Rule address, phase, and activation-time configuration payload.
    /// @param module Contract implementing `IRuleModule`.
    /// @param phase Deterministic phase in which the rule should execute.
    /// @param configData ABI-encoded rule configuration for a specific activation.
    struct RuleConfig {
        address module;
        RulePhase phase;
        bytes configData;
    }

    /// @notice Input used to create a namespace activation.
    /// @param registry ENSv2 registry where subnames are minted.
    /// @param parentNode Namehash of the parent name, e.g. alice.eth.
    /// @param resolver Default resolver assigned to minted subnames.
    /// @param buyerRoleBitmap ENSv2 registry roles granted to subname buyers.
    /// @param rules Ordered rule modules that validate and price mints/renewals.
    /// @param paymentModule Optional module that collects payment from the payer; required when pricing can return non-zero.
    /// @param postHooks Hooks called after the ENSv2 registry mint succeeds.
    struct ActivationConfig {
        IPermissionedRegistry registry;
        bytes32 parentNode;
        address resolver;
        uint256 buyerRoleBitmap;
        RuleConfig[] rules;
        ModuleConfig paymentModule;
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
    struct Activation {
        address owner;
        IPermissionedRegistry registry;
        bytes32 parentNode;
        address resolver;
        uint256 buyerRoleBitmap;
        bool active;
        address paymentModule;
    }

    /// @notice Runtime data supplied by a minter.
    /// @dev Data is split by rule/hook so buyers only provide proof/input data,
    ///      not activation configuration.
    /// @param ruleData Runtime data for each configured rule.
    /// @param paymentData Runtime data for the payment module.
    /// @param postHookData Runtime data for each post-mint hook.
    struct RuntimeData {
        bytes[] ruleData;
        bytes paymentData;
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

    /// @notice Compact rule output consumed by the controller rule engine.
    /// @param decision Rule decision. Rules may also revert with richer errors.
    /// @param priceOp Price operation applied by the controller.
    /// @param bps Basis points used by percentage operations.
    /// @param token Payment token for absolute price operations.
    /// @param amount Amount used by absolute price operations.
    /// @param addFlags Flags to add to the accumulated evaluation state.
    /// @param requireFlags Flags required to already exist in the evaluation state.
    struct RuleOutput {
        Decision decision;
        PriceOp priceOp;
        uint16 bps;
        address token;
        uint256 amount;
        uint256 addFlags;
        uint256 requireFlags;
    }
}
