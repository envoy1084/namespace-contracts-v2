# Namespace Issuance Gas Benchmarks

These benchmarks isolate Namespace subname issuance paths. Activations and approvals are created in `setUp()`, then each benchmark test performs one `controller.mint(...)`.

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
| `testBenchmark_freeMint_noPolicyNoPricing()` | 199423 | 199423 | $0.059827 | $0.299135 | $0.598269 | $1.794807 | $2.991345 |
| `testBenchmark_freeMint_onePolicy()` | 211729 | 211729 | $0.063519 | $0.317594 | $0.635187 | $1.905561 | $3.175935 |
| `testBenchmark_freeMint_threePolicies()` | 244039 | 244039 | $0.073212 | $0.366059 | $0.732117 | $2.196351 | $3.660585 |
| `testBenchmark_freeMint_fivePolicies()` | 281105 | 281105 | $0.084332 | $0.421658 | $0.843315 | $2.529945 | $4.216575 |
| `testBenchmark_erc20FixedPrice_noPolicy()` | 250030 | 250030 | $0.075009 | $0.375045 | $0.750090 | $2.250270 | $3.750450 |
| `testBenchmark_lengthPricing_twoPolicies()` | 293150 | 293150 | $0.087945 | $0.439725 | $0.879450 | $2.638350 | $4.397250 |
| `testBenchmark_erc20Split_threePolicies()` | 329125 | 329125 | $0.098738 | $0.493688 | $0.987375 | $2.962125 | $4.936875 |
| `testBenchmark_fullStack_fivePoliciesTwoPricingSplitHook()` | 505912 | 505912 | $0.151774 | $0.758868 | $1.517736 | $4.553208 | $7.588680 |

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
