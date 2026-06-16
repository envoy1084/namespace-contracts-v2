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
| `testBenchmark_freeMint_noPolicyNoPricing()` | 202899 | 202899 | $0.060870 | $0.304349 | $0.608697 | $1.826091 | $3.043485 |
| `testBenchmark_freeMint_onePolicy()` | 215205 | 215205 | $0.064562 | $0.322808 | $0.645615 | $1.936845 | $3.228075 |
| `testBenchmark_freeMint_threePolicies()` | 247515 | 247515 | $0.074255 | $0.371273 | $0.742545 | $2.227635 | $3.712725 |
| `testBenchmark_freeMint_fivePolicies()` | 296402 | 296402 | $0.088921 | $0.444603 | $0.889206 | $2.667618 | $4.446030 |
| `testBenchmark_erc20FixedPrice_noPolicy()` | 256521 | 256521 | $0.076956 | $0.384781 | $0.769563 | $2.308689 | $3.847815 |
| `testBenchmark_lengthPricing_twoPolicies()` | 299641 | 299641 | $0.089892 | $0.449462 | $0.898923 | $2.696769 | $4.494615 |
| `testBenchmark_erc20Split_threePolicies()` | 335616 | 335616 | $0.100685 | $0.503424 | $1.006848 | $3.020544 | $5.034240 |
| `testBenchmark_fullStack_fivePoliciesTwoPricingSplitHook()` | 524245 | 524245 | $0.157274 | $0.786367 | $1.572735 | $4.718205 | $7.863675 |

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
