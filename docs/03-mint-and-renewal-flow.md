# Mint And Renewal Flow

Mint and renew are the buyer-facing execution paths. Both load an activation, validate runtime data sizes, run policies, compose price, call the ENSv2 registry, collect payment, process funds, and then run post hooks.

## Runtime Data

`NamespaceTypes.RuntimeData` is supplied per mint or renewal:

| Field | Used by |
| --- | --- |
| `policyData[]` | One entry per policy module. |
| `pricingData[]` | One entry per pricing module. |
| `paymentData` | Payment module. |
| `processorData` | Processor module. |
| `postHookData[]` | One entry per post-hook module. |

The controller checks that array lengths match the activation. This prevents accidental proof/config misalignment.

Runtime data is not configuration. Configuration is stored during activation, while runtime data proves facts that can change per buyer or per label. For example, `ReservationPolicy` stores one Merkle root during activation, and a buyer supplies `ReservationPolicy.ProofData` at the policy's array index when minting a reserved label.

```solidity
runtimeData.policyData[reservationPolicyIndex] = abi.encode(
    ReservationPolicy.ProofData({
        account: reservedBuyer,
        expiry: reservationExpiry,
        proof: merkleProof
    })
);
```

## Mint Sequence

```mermaid
sequenceDiagram
    participant Buyer
    participant Controller as NamespaceController
    participant Registry as ENSv2 PermissionedRegistry
    participant Policy as Policies
    participant Pricing as Pricing Modules
    participant Payment as Payment Module
    participant Processor as Processor
    participant Hook as Post Hooks

    Buyer->>Controller: mint(activationId, label, duration, runtimeData)
    Controller->>Controller: require duration > 0 and activation active
    Controller->>Controller: check runtime data lengths
    Controller->>Controller: build MintContext
    loop each policy
        Controller->>Policy: checkMint(ctx, policyData[i])
    end
    loop each pricing module
        Controller->>Pricing: quoteMint(ctx, currentPrice, pricingData[i])
        Pricing-->>Controller: updated price
    end
    Controller->>Registry: register(label, buyer, zeroSubregistry, resolver, buyerRoles, expiry)
    Registry-->>Controller: tokenId
    Controller->>Payment: collectMint{value}(ctx, price, paymentData)
    opt processor configured
        Controller->>Processor: processMint(ctx, price, processorData)
    end
    loop each post hook
        Controller->>Hook: afterMint(ctx, tokenId, postHookData[i])
    end
    Controller-->>Buyer: tokenId
```

## Mint Context

`MintContext` gives modules all common facts:

- `activationId`;
- `buyer`;
- `payer`;
- registry;
- parent node;
- label and label hash;
- duration and expiry;
- resolver;
- buyer role bitmap.

Today `buyer` and `payer` are both `msg.sender`. A future permit or sponsored mint module could extend runtime/payment behavior without changing policy and pricing interfaces.

## Renewal Sequence

```mermaid
sequenceDiagram
    participant Payer
    participant Controller as NamespaceController
    participant Registry as ENSv2 PermissionedRegistry
    participant Policy as Policies
    participant Pricing as Pricing Modules
    participant Payment as Payment Module
    participant Processor as Processor
    participant Hook as Post Hooks

    Payer->>Controller: renew(activationId, label, duration, runtimeData)
    Controller->>Controller: require duration > 0 and activation active
    Controller->>Registry: getState(labelHash)
    Registry-->>Controller: REGISTERED or RESERVED
    Controller->>Controller: newExpiry = state.expiry + duration
    Controller->>Controller: build RenewContext
    loop each policy
        Controller->>Policy: checkRenew(ctx, policyData[i])
    end
    loop each pricing module
        Controller->>Pricing: quoteRenew(ctx, currentPrice, pricingData[i])
    end
    Controller->>Payment: collectRenew{value}(ctx, price, paymentData)
    opt processor configured
        Controller->>Processor: processRenew(ctx, price, processorData)
    end
    Controller->>Registry: renew(tokenId, newExpiry)
    loop each post hook
        Controller->>Hook: afterRenew(ctx, postHookData[i])
    end
    Controller-->>Payer: newExpiry
```

## Execution Order Matters

The current mint order is deliberate:

1. policies before pricing/payment;
2. pricing before registry write;
3. registry write before payment settlement;
4. payment and optional processor before post hooks;
5. hooks after registry write.

Mint does not preflight `getState` because `PermissionedRegistry.register` already enforces availability and reserved-label rules. The controller calls `register` before payment settlement, so an unavailable label reverts before any payment transfer. If payment, processor, or hook execution later reverts, the whole transaction reverts, including the registry write and any ERC20 transfers already made in the same transaction.

Renewal still reads registry state first because it needs the existing token id and expiry to compute the new expiry.

Post hooks run after the registry mutation because they may need the minted token id or a resolver node that should only be updated after a successful mint.
