# Namespace Issuance Gas Benchmarks

These benchmarks isolate Namespace subname issuance paths. Activations and approvals are created in `setUp()`, then each benchmark test performs one `controller.mint(...)`.

Each benchmark is end to end for the Namespace mint path: buyer calls `NamespaceController.mint`, configured policies are checked, pricing modules are evaluated, ERC20 payment is collected, the processor and post-hooks run when configured, and the mint is executed against the official ENSv2 `PermissionedRegistry` implementation from `lib/contracts-v2`.

Reference: [Foundry gas tracking](https://www.getfoundry.sh/forge/gas-tracking).

Run only benchmark tests:

```sh
forge snapshot --match-path 'test/benchmarks/*.t.sol' --snap test/benchmarks/.gas-snapshot
```

Assumptions:

- ETH price: `$3000`
- USD cost formula: `gasUsed * gasPriceGwei * 1e-9 * 3000`
- `Gas consumed @ 1 gwei` is the transaction fee in gwei at a 1 gwei gas price.

| Benchmark | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_freeMint_noPolicyNoPricing()` | 202829 | 202829 | $0.060849 | $0.304244 | $0.608487 | $1.825461 | $3.042435 |
| `testBenchmark_freeMint_onePolicy()` | 215135 | 215135 | $0.064541 | $0.322703 | $0.645405 | $1.936215 | $3.227025 |
| `testBenchmark_freeMint_threePolicies()` | 247445 | 247445 | $0.074233 | $0.371167 | $0.742335 | $2.227005 | $3.711675 |
| `testBenchmark_freeMint_fivePolicies()` | 284511 | 284511 | $0.085353 | $0.426767 | $0.853533 | $2.560599 | $4.267665 |
| `testBenchmark_erc20FixedPrice_noPolicy()` | 253436 | 253436 | $0.076031 | $0.380154 | $0.760308 | $2.280924 | $3.801540 |
| `testBenchmark_lengthPricing_twoPolicies()` | 296556 | 296556 | $0.088967 | $0.444834 | $0.889668 | $2.669004 | $4.448340 |
| `testBenchmark_erc20Split_threePolicies()` | 332531 | 332531 | $0.099759 | $0.498797 | $0.997593 | $2.992779 | $4.987965 |
| `testBenchmark_fullStack_fivePoliciesTwoPricingSplitHook()` | 509318 | 509318 | $0.152795 | $0.763977 | $1.527954 | $4.583862 | $7.639770 |

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
