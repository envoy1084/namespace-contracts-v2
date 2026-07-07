# Architecture Decision History

This note records the major Namespace architecture paths that have already been explored before deployment. The goal is to avoid circling back to designs that looked attractive but failed either composition, gas, or product requirements.

## Current Direction

The current candidate architecture is:

```text
activation stores ordered rules + payment + hooks
each rule returns one compact RuleOutput
the controller applies strict phase/op semantics
payment collects one final price
hooks run only after registry success
```

For now, do not add composite packs as a first implementation step. They can be introduced later as optimized modules if benchmarks prove a specific common flow deserves them.

The immediate experiment is:

```text
make the existing compact effect engine stricter
benchmark it against the current rule profiles
keep it only if gas stays comparable
```

## Tried Path 1: Separate Policy, Pricing, Processor Modules

Earlier architecture:

```text
policies decide if mint is allowed
pricing modules compute price
processor modules collect/split payment
post hooks run after mint
```

Representative removed files:

```text
src/interfaces/IPolicyModule.sol
src/interfaces/IPricingModule.sol
src/interfaces/IProcessorModule.sol
src/modules/policies/*
src/modules/pricing/*
src/modules/processors/*
```

Why it seemed good:

- clean mental separation;
- easy to explain as "checks, pricing, payment";
- each module interface was narrow;
- early benchmarks could isolate each category.

Why it did not work:

| Problem | Example |
| --- | --- |
| Real features cross boundaries | A reservation both gates a label and overrides price. |
| Proof verification duplicated | A whitelist proof may be needed once for eligibility and again for discount. |
| Ordering became fragile | Pricing had to know whether eligibility already accepted a special claim. |
| Runtime data got awkward | The same claim/proof could need to be passed to multiple module arrays. |
| UX became misleading | Users think "reserved name costs 1000 USDC", not "reservation policy plus pricing policy plus processor". |
| More module calls | Common flows paid for multiple external calls even when one proof drove all effects. |

Decision:

```text
Do not return to separate policy/pricing modules as the core architecture.
```

The product needs modules that can both decide eligibility and modify price.

## Tried Path 2: Composite Policy And Composite Pricing

Earlier architecture included composite modules such as:

```text
CompositeMintPolicy
CompositePricing
```

Why it seemed good:

- one module could aggregate several checks;
- caller could pass several sub-configs;
- fewer top-level controller concerns.

Why it did not work as the base model:

| Problem | Reason |
| --- | --- |
| It moved orchestration into modules | The controller lost clear global semantics. |
| It still separated eligibility and pricing | Composite policy and composite pricing were still two worlds. |
| It duplicated engine behavior | Each composite module started to become a mini-controller. |
| It was harder to audit | Ordering and failure semantics lived inside arbitrary module code. |
| It did not solve all cross-effects | A claim that both gates and prices still needed a special bridge. |

Decision:

```text
Do not make arbitrary composite policy/pricing modules the foundation.
```

Future optimized packs can exist, but they should be explicit sale modules that return the same compact rule output model. They are an optimization path, not the initial architecture.

## Tried Path 3: Loose Unified Rules

Current architecture moved toward unified rules:

```text
IRuleModule.evaluateMint/evaluateRenew -> RuleOutput
RuleOutput = decision + priceOp + flags
```

Why it is better:

- one module can verify one proof once;
- one output can block, pass, discount, or override price;
- runtime data is per rule, not duplicated across policy/pricing arrays;
- the controller owns final price composition;
- payment modules only collect, they do not price.

What is still not good enough:

| Issue | Current risk |
| --- | --- |
| Phases are advisory | A `GUARD` rule can technically return a price operation. |
| Conflicts are loose | Multiple `SET_BASE` or `OVERRIDE` operations silently last-win. |
| Discounts can hide misconfigurations | A discount before base price just discounts zero. |
| Flags are global | Third-party modules can accidentally collide on flag bits. |
| Same module instance cannot repeat safely | Module config is keyed by `activationId`, so repeated module address can overwrite itself. |

Decision:

```text
Keep unified rules, but make the engine strict.
```

The strict engine should be tried before changing interfaces or introducing packs.

## Rejected Path 4: Dynamic Effect Arrays

Proposed alternative:

```solidity
struct Effect {
    EffectKind kind;
    bytes data;
}

function evaluateMint(...) external returns (Effect[] memory);
```

Why it seemed good:

- maximum expressiveness;
- one rule could emit many effects;
- easy to model future integrations generically.

Why it is not right for the hot path:

| Problem | Gas/complexity impact |
| --- | --- |
| Dynamic return array | More ABI encoding/decoding and memory allocation. |
| Dynamic effect payloads | More copying and parsing per rule. |
| Per-effect loop | More controller branches on every mint. |
| Unbounded output | Harder to cap gas and audit. |
| Conflict matrix grows | Multiple effects from multiple modules create more precedence cases. |

Decision:

```text
Do not use dynamic Effect[] for the generic mint path.
```

The hot path should keep one compact output per rule. More complex behavior should be handled inside a dedicated rule or quote verifier.

## Deferred Path 5: Composite Packs

Composite packs are still useful, but not first.

Why defer them now:

- if Alice only needs two policies, passing two rules is simpler;
- packs add more product-specific contract surface;
- premature packs can freeze assumptions before the strict engine is benchmarked;
- the current goal is to learn whether stricter semantics can be added without gas regression.

When packs become worth it:

| Signal | Meaning |
| --- | --- |
| Many users choose the same 4-6 rule bundle | A pack can reduce repeated external calls. |
| A high-volume sale needs cheaper mint gas | A pack can compile common checks into one call. |
| One proof must drive many effects | A pack can verify once and apply internal precedence. |
| Benchmarks show external call overhead dominates | A pack is justified by data. |

Decision:

```text
Do not implement packs in the current strict-engine spike.
Keep the architecture pack-compatible for the future.
```

## Current Research Hypothesis

The strict compact-effect architecture should improve safety and composability without materially increasing gas if implemented as:

```text
same IRuleModule interface
same RuleOutput shape
phase passed into the controller effect application
phase/op matrix enforced by cheap branches or bit masks
price state tracked with compact status bits
extra tests for invalid outputs
benchmarks against existing policy profiles
```

The gas success condition is:

```text
common mint scenarios should stay near the current call-only benchmark profile.
```

If strict checks add meaningful overhead, optimize the check implementation before changing the architecture.

## Next Implementation Questions

These are the questions the strict-engine spike must answer:

1. How much gas does phase/op validation add to `mint.three_rules_erc20`?
2. How much gas does price-state validation add to `mint.whitelist_erc20` and `mint.reservation_split`?
3. Does strict validation break legitimate existing module configurations?
4. Should phase/op compatibility be checked at activation, mint, or both?
5. Should repeated `SET_BASE` and `OVERRIDE` always revert?
6. Should discounts before base price revert?
7. Should flags remain global or should official flag ranges be reserved?

The implementation should answer these with tests and benchmarks before replacing the current loose behavior everywhere.

## Strict Engine Spike Result

The strict engine was implemented directly in the current contract names. No composite packs were added.

Implemented changes:

- the controller passes the configured rule phase into output application;
- the controller rejects price operations that do not match the rule phase;
- the controller tracks base-price, price-mutated, override, discount, and token-set state with status bits;
- repeated base prices, discounts before any price exists, and price changes after override now revert;
- focused tests cover illegal phase/op combinations and a valid base-price-then-discount flow.

Benchmark result:

| Scenario | Loose engine | Strict engine | Delta |
| --- | ---: | ---: | ---: |
| Free no-rule mint | `164,818` | `164,818` | `0` |
| One fixed-price ERC20 mint | `222,268` | `223,261` | `+993` |
| Three-rule ERC20 mint | `259,427` | `260,191` | `+764` |
| Whitelist ERC20 mint | `317,250` | `318,031` | `+781` |
| Reservation plus split mint | `369,718` | `372,106` | `+2,388` |
| All-rules split mint, no resolver writes | `566,676` | `571,297` | `+4,621` |
| All-rules split mint, three resolver writes | `648,634` | `653,255` | `+4,621` |
| Three-rule ERC20 renewal | `150,724` | `151,488` | `+764` |

Decision:

```text
Keep the strict compact-effect architecture as the current architecture.
Do not introduce composite packs now.
Use packs later only when product usage and gas benchmarks justify them.
```

Why this is acceptable:

- the common three-rule sale adds less than one thousand gas;
- Merkle proofs, ERC20 payment, registry writes, and resolver hooks dominate real mint cost;
- strict semantics remove dangerous misconfigurations without changing the public rule interface;
- Alice can still activate with only the two or three rules she actually needs.
