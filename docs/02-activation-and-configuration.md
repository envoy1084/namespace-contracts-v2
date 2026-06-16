# Activation And Configuration

Activation is the setup transaction from the namespace owner. It stores the sale and tells each module to store its activation-specific parameters.

## Preconditions

Before activation:

1. The target ENSv2 registry must exist.
2. The namespace owner must have root registrar admin authority on that registry.
3. The `NamespaceController` must have root `ROLE_REGISTRAR` and `ROLE_RENEW` on the same registry.
4. A payment module is required when pricing modules can return a non-zero price. Free activations can use zero payment and zero processor.
5. If module approval is required, every configured module must be approved by the controller owner.

## Activation Config

`NamespaceTypes.ActivationConfig` is the full activation payload:

| Field | Purpose |
| --- | --- |
| `registry` | Official ENSv2 `IPermissionedRegistry` where labels are minted. |
| `parentNode` | Parent ENS node, such as the namehash for `alice.eth`. |
| `resolver` | Default resolver written during registry mint. |
| `buyerRoleBitmap` | ENSv2 roles granted to the buyer on the minted label. |
| `policies` | Ordered policy modules that must all pass. |
| `pricingModules` | Ordered pricing modules that compose the final price. |
| `paymentModule` | Optional single module that collects funds. Required for paid activations. |
| `processor` | Optional single module that distributes or accounts for collected funds. Use zero for direct settlement. |
| `postHooks` | Ordered hooks executed after registry writes. |

Each module config is:

```solidity
struct ModuleConfig {
    address module;
    bytes configData;
}
```

`configData` is ABI-decoded by the target module. For example, `LabelLengthPolicy` expects `LabelLengthPolicy.Params`.

## Activation Sequence

```mermaid
sequenceDiagram
    participant Owner as Namespace Owner
    participant Controller as NamespaceController
    participant Registry as ENSv2 Registry
    participant Module as Module Contracts

    Owner->>Controller: activate(config)
    Controller->>Controller: require registry and paid activations have payment
    Controller->>Registry: hasRootRoles(REGISTRAR_ADMIN, owner)
    Registry-->>Controller: true
    Controller->>Registry: hasRootRoles(REGISTRAR | RENEW, controller)
    Registry-->>Controller: true
    Controller->>Controller: activationId = hash(chain, registry, parentNode, owner, nonce)
    Controller->>Controller: store activation metadata
    loop policies
        Controller->>Module: configure(activationId, configData)
    end
    loop pricing modules
        Controller->>Module: configure(activationId, configData)
    end
    opt payment configured
        Controller->>Module: configure payment
    end
    opt processor configured
        Controller->>Module: configure processor
    end
    loop post hooks
        Controller->>Module: configure(activationId, configData)
    end
    Controller-->>Owner: activationId
```

## Stored Data

The controller stores only orchestration data:

- activation owner;
- registry;
- parent node;
- resolver;
- buyer role bitmap;
- active status;
- compact module address list references.

Each module stores its own configuration keyed by `activationId`.

This keeps the controller generic and makes future features additive. A future "human verification" feature, for example, can be a new policy module with the same `configure/checkMint/checkRenew` shape.

Module address lists use a gas-oriented hybrid layout:

- zero modules: store no module data;
- one module: store the module address directly;
- two or more modules: pack 20-byte addresses into a Solady `SSTORE2` pointer.

This avoids storage slots for empty/free activations, keeps common one-module paths cheap, and avoids expensive multi-slot dynamic storage for larger policy/pricing/hook stacks.

No-pricing activations can set payment and processor to zero. They skip settlement calls during zero-price mint and renewal, which avoids paying proxy-call overhead for free sales.

For direct-settlement paid sales, set `processor.module` to zero and configure the payment module to send funds directly to the final recipient. Use a processor only when an extra accounting or distribution step is required, such as ERC20 revenue splits.

## Activation Ownership

Activation ownership is separate from ENS token ownership, but it is guarded by ENSv2 registry authority.

The controller checks root registrar admin authority:

- when creating an activation;
- when enabling or disabling an activation;
- when transferring activation ownership;
- for the new owner during ownership transfer.

This prevents an old activation owner from continuing to manage a sale after losing registry admin authority.

## Updating Activation Parameters

Activation owners can update configuration for modules already attached to an activation:

```solidity
updateModuleConfig(activationId, MODULE_KIND_POLICY, 0, newConfigData)
```

The controller verifies:

- the activation exists;
- `msg.sender` is the activation owner;
- the activation owner still has registry admin authority;
- the requested module kind and index exist.

Then it calls `configure(activationId, newConfigData)` on the existing module. This updates module parameters without changing the module address list. Examples:

- update `SaleWindowPolicy` times;
- rotate `ReservationPolicy` or `MerkleWhitelistPolicy` roots;
- change fixed-price or length-price values;
- update payment recipient or split recipients. If an activation was created with a zero processor, there is no processor module to update.

## Module Approval Mode

Module allowlisting is enabled by default. The controller owner approves modules by kind:

```solidity
setModuleApproval(MODULE_KIND_POLICY, policyModule, true)
setModuleApproval(MODULE_KIND_PRICING, pricingModule, true)
setModuleApproval(MODULE_KIND_PAYMENT, paymentModule, true)
setModuleApproval(MODULE_KIND_PROCESSOR, processorModule, true)
```

When approval mode is enabled, activation can only use modules approved for the exact module kind where they are used. A module approved as pricing is not approved as a policy. This is useful for a curated production deployment where user activations should not point at arbitrary external modules.
