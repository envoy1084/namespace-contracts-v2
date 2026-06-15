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
| `testBenchmark_freeMint_noPolicyNoPricing()` | 202877 | 202877 | $0.060863 | $0.304316 | $0.608631 | $1.825893 | $3.043155 |
| `testBenchmark_freeMint_onePolicy()` | 215183 | 215183 | $0.064555 | $0.322775 | $0.645549 | $1.936647 | $3.227745 |
| `testBenchmark_freeMint_threePolicies()` | 247493 | 247493 | $0.074248 | $0.371240 | $0.742479 | $2.227437 | $3.712395 |
| `testBenchmark_freeMint_fivePolicies()` | 284559 | 284559 | $0.085368 | $0.426839 | $0.853677 | $2.561031 | $4.268385 |
| `testBenchmark_erc20FixedPrice_noPolicy()` | 253495 | 253495 | $0.076049 | $0.380243 | $0.760485 | $2.281455 | $3.802425 |
| `testBenchmark_lengthPricing_twoPolicies()` | 296615 | 296615 | $0.088985 | $0.444923 | $0.889845 | $2.669535 | $4.449225 |
| `testBenchmark_erc20Split_threePolicies()` | 332590 | 332590 | $0.099777 | $0.498885 | $0.997770 | $2.993310 | $4.988850 |
| `testBenchmark_fullStack_fivePoliciesTwoPricingSplitHook()` | 509401 | 509401 | $0.152820 | $0.764102 | $1.528203 | $4.584609 | $7.641015 |

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
