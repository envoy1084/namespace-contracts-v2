# Activation Lifecycle

Activation turns a namespace owner's intended sale configuration into executable controller and module state.

## Zero-To-One Activation Flow

```text
1. Deploy and initialize controller.
2. Deploy and initialize modules.
3. Controller owner approves modules.
4. Controller owner sets root ENSv2 registry.
5. ENSv2 registry admin grants controller register and renew roles.
6. Namespace owner calls activate(config).
7. Controller validates registry, permissions, durations, modules, and phases.
8. Controller stores activation.
9. Controller calls configure on every configured module.
10. Activation id is returned and sale can be used.
```

## Required Pre-State

Before `activate`:

| Requirement | Why |
| --- | --- |
| Controller proxy initialized | Sets owner and enables module approval enforcement. |
| `rootRegistry` set | Needed for canonical parent validation. |
| Modules initialized with controller address | `configure` and runtime calls require `onlyController`. |
| Modules approved by kind when approvals are required | Activation rejects unapproved modules. |
| Activation caller has ENSv2 root admin roles | Caller must be authorized for the namespace. |
| Controller has ENSv2 register and renew roles | Controller must be able to execute future mints/renews. |

## Activation Sequence

```mermaid
sequenceDiagram
    participant Owner as "Namespace owner"
    participant Controller as "NamespaceController"
    participant Registry as "ENSv2 registry"
    participant Rule as "Rule modules"
    participant Payment as "Payment module"
    participant Hook as "Post hooks"

    Owner->>Controller: activate(config)
    Controller->>Controller: require registry != zero
    Controller->>Controller: require rootRegistry configured
    Controller->>Registry: walk parent chain to rootRegistry
    Controller->>Controller: require computed node == config.parentNode
    Controller->>Controller: require valid duration bounds
    Controller->>Registry: hasRootRoles(admin roles, Owner)
    Registry-->>Controller: true
    Controller->>Registry: hasRootRoles(register and renew roles, Controller)
    Registry-->>Controller: true
    Controller->>Controller: validate modules and sorted rule phases
    Controller->>Controller: derive activationId and store activation
    loop "rules"
        Controller->>Rule: configure(activationId, configData)
    end
    opt "payment module != zero"
        Controller->>Payment: configure(activationId, configData)
    end
    loop "post hooks"
        Controller->>Hook: configure(activationId, configData)
    end
    Controller-->>Owner: activationId
```

## Checks In Order

| Order | Check | Why it exists |
| --- | --- | --- |
| 1 | `config.registry != address(0)` | Registry calls cannot target zero address. |
| 2 | `rootRegistry != address(0)` | Parent-chain validation needs a canonical root. |
| 3 | Registry parent chain computes `config.parentNode` | Prevents a caller from pairing one registry with another namehash. |
| 4 | `config.maxDuration != 0` | Prevents an activation that can never accept a valid duration. |
| 5 | `config.minDuration <= config.maxDuration` | Prevents impossible duration bounds. |
| 6 | Payment module is approved if non-zero | Payment module controls asset movement. |
| 7 | Caller has registry admin roles | Sale config must be created by an authorized namespace admin. |
| 8 | Controller has register/renew roles | Future runtime calls need registry execution authority. |
| 9 | Rule count and hook count are at most `255` | Counts are stored as `uint8`. |
| 10 | Every configured module is non-zero and approved for its kind | Prevents invalid and uncurated external execution. |
| 11 | Rule phases are non-descending | Ensures deterministic rule pipeline. |

## Activation Storage

The controller stores:

```text
owner = msg.sender
registry = config.registry
parentNode = config.parentNode
resolver = config.resolver
buyerRoleBitmap = config.buyerRoleBitmap
minDuration = config.minDuration
maxDuration = config.maxDuration
active = true
rules = compact rule list
paymentModule = config.paymentModule.module
postHooks = compact hook list
```

Then it emits:

```text
ActivationCreated(activationId, owner, registry, parentNode)
ActivationStatusChanged(activationId, true)
```

Although the activation is stored before module `configure` calls, the whole `activate` call is atomic. If any `configure` call reverts, storage and events revert.

## Current Versus Recommended Activation Multiplicity

Current implementation:

```text
The same registry and parent node can have multiple activation ids because activation ids include a nonce.
```

Recommended product model:

```text
Only one activation should be current for new mints for a namespace.
Historical activations should remain addressable for renewals unless explicitly migrated or disabled.
```

Why this distinction matters:

| Design | Issue |
| --- | --- |
| One activation forever | Cannot replace immutable module stacks when sale architecture changes. |
| Multiple live mint activations | Buyers and indexers see conflicting sale configs. |
| One current mint activation plus historical renewal activations | Clear user-facing sale path while preserving renewal behavior. |

Recommended future state:

```solidity
mapping(address registry => bytes32 activationId) currentActivationByRegistry;
```

Then `mint` can require that the supplied activation id is the current one for the registry. `renew` should continue to use the activation that originally minted the label through `labelActivations`.

The detailed design is in [Activation Interface Recommendations](./16-activation-interface-recommendations.md).

## Module Configure Phase

Each module receives:

```solidity
configure(bytes32 activationId, bytes calldata configData)
```

Design rule for modules:

| Requirement | Reason |
| --- | --- |
| Restrict `configure` to the controller | Prevents arbitrary accounts from changing activation module parameters. |
| Decode exactly the documented params type | Keeps frontend/backend encoding deterministic. |
| Store by `activationId` | Allows one module to serve many activations. |
| Validate config immediately | Bad config should fail before activation succeeds. |

## Updating Module Config

`updateModuleConfig(activationId, kind, index, configData)` updates an existing module.

Sequence:

```mermaid
sequenceDiagram
    participant Owner as "Activation owner"
    participant Controller as "NamespaceController"
    participant Module as "Existing module"
    participant Registry as "ENSv2 registry"

    Owner->>Controller: updateModuleConfig(activationId, kind, index, configData)
    Controller->>Controller: require known kind
    Controller->>Controller: load activation
    Controller->>Controller: require caller is activation owner
    Controller->>Registry: hasRootRoles(admin roles, activation owner)
    Registry-->>Controller: true
    Controller->>Controller: resolve module at kind and index
    Controller->>Controller: require module approved for kind
    Controller->>Module: configure(activationId, configData)
    Controller-->>Owner: emit ModuleConfigUpdated
```

What can be changed:

| Can update | Examples |
| --- | --- |
| Existing rule parameters | Fixed prices, whitelist root, reservation root, sale window. |
| Existing payment parameters | Recipient, split recipients, split bps. |
| Existing hook parameters | Hook-specific config, if the hook stores any. |

What cannot be changed inside the same activation:

| Cannot update | Required action |
| --- | --- |
| Rule module address | Create a new activation. |
| Rule order or phase | Create a new activation. |
| Add/remove hooks | Create a new activation. |
| Payment module address | Create a new activation. |
| Registry, parent node, resolver, duration bounds, buyer roles | Create a new activation. |

## Activation Status

`setActivationStatus(activationId, active)` changes `activation.active`.

Checks:

| Check | Why |
| --- | --- |
| Activation exists | Avoids writing unknown ids. |
| Caller is activation owner | Prevents third-party pause/unpause. |
| Activation owner still has registry admin roles | Prevents stale admin from managing sale state. |

`active == false` blocks both `mint` and `renew`.

## PauseRule Versus Activation Status

There are two pause mechanisms:

| Mechanism | Where stored | Who controls | Effect |
| --- | --- | --- | --- |
| Activation status | Controller | Activation owner | Blocks before rule evaluation. |
| `PauseRule` | Rule module | Activation owner | Blocks when rule is evaluated. |

Use activation status for whole-activation operational shutdown. Use `PauseRule` when pause behavior should be part of the configured rule stack and visible as a rule.

## Ownership Transfer

`transferActivationOwnership(activationId, newOwner)`:

| Check | Why |
| --- | --- |
| `newOwner != address(0)` | Prevents orphaned activations. |
| Caller is current activation owner | Prevents unauthorized transfer. |
| Current owner still has registry admin roles | Ensures current owner is still valid. |
| New owner has registry admin roles | Ensures future owner can manage the namespace sale. |

This changes only Namespace activation ownership. It does not transfer ENSv2 name ownership or registry roles.
