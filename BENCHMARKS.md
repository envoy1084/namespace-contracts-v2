# Namespace Issuance Gas Benchmarks

These benchmarks isolate Namespace subname issuance paths. Activations and approvals are created in `setUp()`, then each benchmark test performs one `controller.mint(...)`.

Each benchmark is end to end for the Namespace mint path: buyer calls `NamespaceController.mint`, configured policies are checked, pricing modules are evaluated, ERC20 payment is collected, the processor and post-hooks run when configured, and the mint is executed against the official ENSv2 `PermissionedRegistry` implementation from `lib/contracts-v2`.

Reference: [Foundry gas tracking](https://www.getfoundry.sh/forge/gas-tracking).

Run and regenerate this file:

```sh
./scripts/generate-benchmarks.sh
```

Assumptions:

- ETH price: `$3000`
- USD cost formula: `gasUsed * gasPriceGwei * 1e-9 * ETH_PRICE_USD`
- `Gas consumed @ 1 gwei` is the transaction fee in gwei at a 1 gwei gas price.

| Benchmark | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_freeMint_noPolicyNoPricing()` | 195107 | 195107 | $0.058532 | $0.292660 | $0.585321 | $1.755963 | $2.926605 |
| `testBenchmark_freeMint_onePolicy()` | 207413 | 207413 | $0.062224 | $0.311120 | $0.622239 | $1.866717 | $3.111195 |
| `testBenchmark_freeMint_threePolicies()` | 239728 | 239728 | $0.071918 | $0.359592 | $0.719184 | $2.157552 | $3.595920 |
| `testBenchmark_freeMint_fivePolicies()` | 288422 | 288422 | $0.086527 | $0.432633 | $0.865266 | $2.595798 | $4.326330 |
| `testBenchmark_erc20FixedPrice_noPolicy()` | 248044 | 248044 | $0.074413 | $0.372066 | $0.744132 | $2.232396 | $3.720660 |
| `testBenchmark_lengthPricing_twoPolicies()` | 291164 | 291164 | $0.087349 | $0.436746 | $0.873492 | $2.620476 | $4.367460 |
| `testBenchmark_erc20Split_threePolicies()` | 326109 | 326109 | $0.097833 | $0.489164 | $0.978327 | $2.934981 | $4.891635 |
| `testBenchmark_fullStack_fivePoliciesTwoPricingSplitHook()` | 514521 | 514521 | $0.154356 | $0.771782 | $1.543563 | $4.630689 | $7.717815 |

## Scenario Notes

| Benchmark | Scenario |
| --- | --- |
| `testBenchmark_freeMint_noPolicyNoPricing()` | Free subname mint with no policies, no pricing modules, no split processor, and no hooks. |
| `testBenchmark_freeMint_onePolicy()` | Free mint with one sale-window policy. |
| `testBenchmark_freeMint_threePolicies()` | Free mint with sale-window, label-length, and ERC20 balance-gate policies. |
| `testBenchmark_freeMint_fivePolicies()` | Free mint with sale-window, label-length, ERC20 gate, reservation, and Merkle whitelist policies. |
| `testBenchmark_erc20FixedPrice_noPolicy()` | ERC20 fixed-price mint with no policies and direct treasury payment. |
| `testBenchmark_lengthPricing_twoPolicies()` | Mint with sale-window and label-length policies, fixed pricing plus length-based pricing, and direct treasury payment. |
| `testBenchmark_erc20Split_threePolicies()` | Mint with three policies, ERC20 fixed pricing, ERC20 payment collection, and split processor payout. |
| `testBenchmark_fullStack_fivePoliciesTwoPricingSplitHook()` | Mint with five policies, fixed plus length pricing, ERC20 split processing, and one post-mint hook. |
