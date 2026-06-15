# Mint And Renewal Flow

Mint and renew are the buyer-facing execution paths. Both load an activation, validate runtime data sizes, run policies, compose price, collect payment, process funds, and call the ENSv2 registry.

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
    Controller->>Registry: getState(labelHash)
    Registry-->>Controller: AVAILABLE
    Controller->>Controller: build MintContext
    loop each policy
        Controller->>Policy: checkMint(ctx, policyData[i])
    end
    loop each pricing module
        Controller->>Pricing: quoteMint(ctx, currentPrice, pricingData[i])
        Pricing-->>Controller: updated price
    end
    Controller->>Payment: collectMint{value}(ctx, price, paymentData)
    Controller->>Processor: processMint(ctx, price, processorData)
    Controller->>Registry: register(label, buyer, zeroSubregistry, resolver, buyerRoles, expiry)
    Registry-->>Controller: tokenId
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
    Controller->>Processor: processRenew(ctx, price, processorData)
    Controller->>Registry: renew(tokenId, newExpiry)
    loop each post hook
        Controller->>Hook: afterRenew(ctx, postHookData[i])
    end
    Controller-->>Payer: newExpiry
```

## Execution Order Matters

The current order is deliberate:

1. availability/state check first;
2. policies before pricing/payment;
3. payment before registry write;
4. processor before registry write;
5. hooks after registry write.

Post hooks run after the registry mutation because they may need the minted token id or a resolver node that should only be updated after a successful mint.

