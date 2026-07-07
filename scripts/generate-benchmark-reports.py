#!/usr/bin/env python3
"""Generate Namespace benchmark reports from a Foundry gas snapshot."""

from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass
from pathlib import Path


SNAPSHOT = Path("test/benchmarks/.gas-snapshot")
BENCHMARK_INDEX = Path("BENCHMARKS.md")
PROFILE_REPORT = Path("PROFILE_BENCHMARKS.md")
SCENARIO_REPORT = Path("SCENARIO_BENCHMARKS.md")
COMPONENTS_TSV = Path("benchmarks/gas-components.tsv")
PROFILE_JSON = Path("benchmarks/profile-gas-report.json")
ETH_PRICE_USD = int(os.environ.get("ETH_PRICE_USD", "3000"))


@dataclass(frozen=True)
class Component:
    key: str
    kind: str
    source: str
    description: str
    gas: int

    @property
    def category(self) -> str:
        return self.key.split(".", 1)[0]


SNAPSHOT_LINE = re.compile(r"^[^:]+:(?P<name>[^\s]+)\(\) \(gas: (?P<gas>\d+)\)$")


def parse_snapshot(path: Path) -> dict[str, int]:
    gas_by_name: dict[str, int] = {}
    for line in path.read_text().splitlines():
        match = SNAPSHOT_LINE.match(line.strip())
        if match:
            gas_by_name[match.group("name")] = int(match.group("gas"))
    return gas_by_name


def humanize(name: str, prefix: str) -> str:
    value = re.sub(prefix, "", name)
    value = re.sub(r"\(\)$", "", value)
    value = value.replace("_", " ")
    out: list[str] = []
    for i, char in enumerate(value):
        previous = value[i - 1] if i else ""
        if char.isupper() and (previous.islower() or previous.isdigit()):
            out.append(" ")
        out.append(char)
    return "".join(out)


def usd(gas: int) -> float:
    return gas * 1e-9 * ETH_PRICE_USD


def absolute(
    components: list[Component],
    gas_by_name: dict[str, int],
    key: str,
    kind: str,
    source: str,
    description: str,
) -> None:
    components.append(Component(key, kind, source, description, gas_by_name[source]))


def delta(
    components: list[Component],
    gas_by_name: dict[str, int],
    key: str,
    kind: str,
    source: str,
    base: str,
    description: str,
) -> None:
    components.append(Component(key, kind, f"{source} - {base}", description, gas_by_name[source] - gas_by_name[base]))


def build_components(gas_by_name: dict[str, int]) -> list[Component]:
    components: list[Component] = []

    absolute(
        components,
        gas_by_name,
        "activation.free_no_rules",
        "exact",
        "testBenchmark_activation_00_pncFreeNoRules",
        "Activation with no rules, no payment, no hooks.",
    )
    absolute(
        components,
        gas_by_name,
        "activation.all_rules_split_five_resolver_writes",
        "exact",
        "testBenchmark_activation_24_pncAllRulesSplitFiveResolverWrites",
        "Activation with every current rule, split payment, and five resolver writes.",
    )

    absolute(
        components,
        gas_by_name,
        "mint.free_no_rules",
        "exact",
        "testBenchmark_mint_00_pncFreeNoRules",
        "Controller mint with no rules, no payment, no hooks.",
    )
    absolute(
        components,
        gas_by_name,
        "mint.fixed_erc20",
        "exact",
        "testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment",
        "Controller mint with fixed price rule and direct ERC20 payment.",
    )
    absolute(
        components,
        gas_by_name,
        "mint.three_rules_erc20",
        "exact",
        "testBenchmark_mint_08_pncThreeRulesERC20PaymentNoResolver",
        "Controller mint with sale window, label length, fixed price, and direct ERC20 payment.",
    )
    absolute(
        components,
        gas_by_name,
        "mint.three_rules_split_two_resolver_writes",
        "exact",
        "testBenchmark_mint_11_pncThreeRulesSplitPaymentTwoResolverWrites",
        "Controller mint with three rules, split payment, and two resolver writes.",
    )
    absolute(
        components,
        gas_by_name,
        "mint.three_rules_premium_split_three_resolver_writes",
        "exact",
        "testBenchmark_mint_13_pncThreeRulesPremiumSplitPaymentThreeResolverWrites",
        "Controller mint with three rules, premium pricing, split payment, and three resolver writes.",
    )
    absolute(
        components,
        gas_by_name,
        "mint.whitelist_erc20",
        "exact",
        "testBenchmark_mint_14_pncFourRulesWhitelistERC20PaymentNoResolver",
        "Controller mint with whitelist proof and direct ERC20 payment.",
    )
    absolute(
        components,
        gas_by_name,
        "mint.reservation_split",
        "exact",
        "testBenchmark_mint_19_pncFiveRulesReservationDiscountSplitNoResolver",
        "Controller mint with reservation and token discount rules plus split payment.",
    )
    absolute(
        components,
        gas_by_name,
        "mint.all_rules_split",
        "exact",
        "testBenchmark_mint_22_pncAllRulesSplitNoResolverWrites",
        "Controller mint with every current rule and split payment, no resolver writes.",
    )
    absolute(
        components,
        gas_by_name,
        "mint.all_rules_split_three_resolver_writes",
        "exact",
        "testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites",
        "Controller mint with every current rule, split payment, and three resolver writes.",
    )
    absolute(
        components,
        gas_by_name,
        "mint.all_rules_split_five_resolver_writes",
        "exact",
        "testBenchmark_mint_24_pncAllRulesSplitFiveResolverWrites",
        "Controller mint with every current rule, split payment, and five resolver writes.",
    )
    absolute(
        components,
        gas_by_name,
        "renew.three_rules_erc20",
        "exact",
        "testBenchmark_renew_00_threeRulesERC20PaymentNoHook",
        "Controller renewal with three rules and direct ERC20 payment.",
    )

    for key, source, description in [
        ("registry.register_no_roles", "testBenchmark_registry_00_registerNoRolesNoResolver", "Direct ENSv2 registry register with owner, no buyer roles, no resolver."),
        ("registry.register_buyer_roles", "testBenchmark_registry_01_registerBuyerRolesNoResolver", "Direct ENSv2 registry register with buyer roles and no resolver."),
        ("registry.register_buyer_roles_resolver", "testBenchmark_registry_02_registerBuyerRolesWithResolver", "Direct ENSv2 registry register with buyer roles and resolver."),
        ("registry.reserve_no_owner", "testBenchmark_registry_03_reserveLabelNoOwner", "Direct ENSv2 registry reserve flow with owner set to zero."),
        ("registry.renew_registered", "testBenchmark_registry_04_renewRegistered", "Direct ENSv2 registry renewal baseline."),
    ]:
        absolute(components, gas_by_name, key, "floor", source, description)

    for key, source, description in [
        ("rule.pause", "testBenchmark_profile_rule_00_pause_evaluateMint", "PauseRule evaluateMint."),
        ("rule.sale_window_open", "testBenchmark_profile_rule_01_saleWindowOpen_evaluateMint", "SaleWindowRule evaluateMint with open zero-bounds config."),
        ("rule.sale_window_bounded", "testBenchmark_profile_rule_02_saleWindowBounded_evaluateMint", "SaleWindowRule evaluateMint with active start/end bounds."),
        ("rule.label_length", "testBenchmark_profile_rule_03_labelLength_evaluateMint", "LabelLengthRule evaluateMint."),
        ("rule.fixed_price_no_overrides", "testBenchmark_profile_rule_04_fixedPriceNoLengthOverrides_evaluateMint", "FixedPriceRule with no length overrides."),
        ("rule.fixed_price_5_fallback", "testBenchmark_profile_rule_05_fixedPriceFiveOverridesFallback_evaluateMint", "FixedPriceRule with five overrides and fallback label."),
        ("rule.fixed_price_5_exact", "testBenchmark_profile_rule_06_fixedPriceFiveOverridesExact_evaluateMint", "FixedPriceRule with five overrides and exact-length hit."),
        ("rule.fixed_price_20_exact", "testBenchmark_profile_rule_07_fixedPriceTwentyOverridesExact_evaluateMint", "FixedPriceRule with twenty overrides and exact-length hit."),
        ("rule.length_premium_5", "testBenchmark_profile_rule_08_lengthPremiumFiveBuckets_evaluateMint", "LengthPremiumRule with five buckets."),
        ("rule.length_premium_5_fallback", "testBenchmark_profile_rule_09_lengthPremiumFiveBucketsFallback_evaluateMint", "LengthPremiumRule with five buckets and fallback bucket."),
        ("rule.length_premium_20", "testBenchmark_profile_rule_10_lengthPremiumTwentyBuckets_evaluateMint", "LengthPremiumRule with twenty buckets."),
        ("rule.token_balance_discount", "testBenchmark_profile_rule_11_tokenBalanceDiscount_evaluateMint", "TokenBalanceRule with minimum balance and discount."),
        ("rule.reservation_10", "testBenchmark_profile_rule_12_reservation10_evaluateMint", "ReservationRule with Merkle set size 10."),
        ("rule.reservation_100", "testBenchmark_profile_rule_13_reservation100_evaluateMint", "ReservationRule with Merkle set size 100."),
        ("rule.reservation_1000", "testBenchmark_profile_rule_14_reservation1000_evaluateMint", "ReservationRule with Merkle set size 1000."),
        ("rule.whitelist_10", "testBenchmark_profile_rule_15_whitelist10_evaluateMint", "WhitelistRule with Merkle set size 10."),
        ("rule.whitelist_100", "testBenchmark_profile_rule_16_whitelist100_evaluateMint", "WhitelistRule with Merkle set size 100."),
        ("rule.whitelist_1000", "testBenchmark_profile_rule_17_whitelist1000_evaluateMint", "WhitelistRule with Merkle set size 1000."),
        ("rule.label_class_number", "testBenchmark_profile_rule_18_labelClassNumber_evaluateMint", "LabelClassRule for numeric labels."),
        ("rule.label_class_letter", "testBenchmark_profile_rule_19_labelClassLetter_evaluateMint", "LabelClassRule for ASCII letter labels."),
        ("rule.label_class_emoji", "testBenchmark_profile_rule_20_labelClassEmoji_evaluateMint", "LabelClassRule for emoji labels."),
        ("rule.usd_oracle", "testBenchmark_profile_rule_21_usdOracle_evaluateMint", "USDOracleRule with Chainlink-compatible oracle."),
    ]:
        absolute(components, gas_by_name, key, "profile", source, description)

    for key, source, description in [
        ("payment.erc20", "testBenchmark_profile_payment_00_collectMintERC20", "Direct ERC20 transferFrom payment module."),
        ("payment.split_2", "testBenchmark_profile_payment_01_collectMintSplitERC20TwoRecipients", "ERC20 split payment to two recipients."),
        ("payment.split_3", "testBenchmark_profile_payment_02_collectMintSplitERC20ThreeRecipients", "ERC20 split payment to three recipients."),
        ("payment.split_5", "testBenchmark_profile_payment_03_collectMintSplitERC20FiveRecipients", "ERC20 split payment to five recipients."),
        ("hook.recording", "testBenchmark_profile_hook_00_recordingPostHook_afterMint", "Recording post-hook profile."),
        ("hook.set_addr_empty", "testBenchmark_profile_hook_01_setAddrToBuyerEmpty_afterMint", "SetAddrToBuyerHook using buyer address."),
        ("hook.set_addr_override", "testBenchmark_profile_hook_02_setAddrToBuyerOverride_afterMint", "SetAddrToBuyerHook using address override."),
        ("hook.batch_resolver_1", "testBenchmark_profile_hook_03_batchResolverHookOneWrite_afterMint", "BatchSetAddrToBuyerHook with one resolver write."),
        ("hook.batch_resolver_3", "testBenchmark_profile_hook_04_batchResolverHookThreeWrites_afterMint", "BatchSetAddrToBuyerHook with three resolver writes."),
        ("hook.batch_resolver_5", "testBenchmark_profile_hook_05_batchResolverHookFiveWrites_afterMint", "BatchSetAddrToBuyerHook with five resolver writes."),
    ]:
        absolute(components, gas_by_name, key, "profile", source, description)

    delta(components, gas_by_name, "delta.guard_rule", "delta", "testBenchmark_mint_01_pncOneGuardRuleFree", "testBenchmark_mint_00_pncFreeNoRules", "Incremental mint cost from adding one guard rule to a free mint.")
    delta(components, gas_by_name, "delta.fixed_erc20_sale", "delta", "testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment", "testBenchmark_mint_00_pncFreeNoRules", "Incremental mint cost from fixed-price rule plus direct ERC20 payment.")
    delta(components, gas_by_name, "delta.split_over_erc20", "delta", "testBenchmark_mint_03_pncOneFixedPriceRuleSplitPayment", "testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment", "Incremental mint cost from split payment instead of direct ERC20 payment.")
    delta(components, gas_by_name, "delta.three_rules_over_fixed_erc20", "delta", "testBenchmark_mint_08_pncThreeRulesERC20PaymentNoResolver", "testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment", "Incremental mint cost from sale window and label-length rules over fixed ERC20 sale.")
    delta(components, gas_by_name, "delta.whitelist_over_three_rules", "delta", "testBenchmark_mint_14_pncFourRulesWhitelistERC20PaymentNoResolver", "testBenchmark_mint_08_pncThreeRulesERC20PaymentNoResolver", "Incremental mint cost from adding whitelist proof to the common three-rule ERC20 sale.")
    delta(components, gas_by_name, "delta.all_rules_over_split_three_rules", "delta", "testBenchmark_mint_22_pncAllRulesSplitNoResolverWrites", "testBenchmark_mint_09_pncThreeRulesSplitPaymentNoResolver", "Incremental mint cost from all rules over three-rule split sale.")
    delta(components, gas_by_name, "delta.batch_resolver_three_writes", "delta", "testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites", "testBenchmark_mint_22_pncAllRulesSplitNoResolverWrites", "Incremental mint cost from three resolver writes on all-rule split sale.")
    delta(components, gas_by_name, "delta.batch_resolver_two_more_writes", "delta", "testBenchmark_mint_24_pncAllRulesSplitFiveResolverWrites", "testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites", "Incremental mint cost from two additional resolver writes.")
    delta(components, gas_by_name, "delta.all_rules_activation", "delta", "testBenchmark_activation_24_pncAllRulesSplitFiveResolverWrites", "testBenchmark_activation_00_pncFreeNoRules", "Incremental activation setup cost from all current rules, split payment, and five resolver writes.")

    return components


def benchmark_rows(gas_by_name: dict[str, int], pattern: str, strip_pattern: str) -> list[str]:
    rows: list[str] = []
    regex = re.compile(pattern)
    strip_regex = re.compile(strip_pattern)
    for name, gas in gas_by_name.items():
        if regex.search(name):
            scenario = humanize(name, strip_regex.pattern)
            rows.append(f"| `{name}()` | {scenario} | {gas} | ${usd(gas):.6f} |")
    return rows


def append_table(lines: list[str], title: str, rows: list[str]) -> None:
    lines.extend(
        [
            f"## {title}",
            "",
            "| Name | Scenario | Gwei used | USD @ 1 gwei |",
            "| --- | --- | ---: | ---: |",
            *rows,
            "",
        ]
    )


def write_components_tsv(components: list[Component]) -> None:
    COMPONENTS_TSV.parent.mkdir(parents=True, exist_ok=True)
    lines = ["key\tkind\tgas\tsource\tdescription"]
    for component in components:
        lines.append(
            f"{component.key}\t{component.kind}\t{component.gas}\t{component.source}\t{component.description}"
        )
    COMPONENTS_TSV.write_text("\n".join(lines) + "\n")


def write_profile_json(components: list[Component]) -> None:
    PROFILE_JSON.parent.mkdir(parents=True, exist_ok=True)
    exact = {component.key: component for component in components if component.kind in {"exact", "floor"}}
    profiles = {component.key: component for component in components if component.kind == "profile"}
    deltas = {component.key: component for component in components if component.kind == "delta"}
    data = {
        "schemaVersion": 1,
        "source": str(SNAPSHOT),
        "ethPriceUsd": ETH_PRICE_USD,
        "estimator": {
            "mintBaseKey": "mint.free_no_rules",
            "activationBaseKey": "activation.free_no_rules",
            "componentCatalog": str(COMPONENTS_TSV),
            "notes": [
                "Profile entries are standalone module-call measurements.",
                "Use exact scenario keys when they match a production configuration.",
                "Use profile keys for rough planning when combining arbitrary rules, payment modules, and hooks.",
            ],
        },
        "profiles": {key: component_json(component) for key, component in profiles.items()},
        "exact": {key: component_json(component) for key, component in exact.items()},
        "deltas": {key: component_json(component) for key, component in deltas.items()},
    }
    PROFILE_JSON.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def component_json(component: Component) -> dict[str, str | int]:
    return {
        "category": component.category,
        "kind": component.kind,
        "gas": component.gas,
        "source": component.source,
        "description": component.description,
    }


def write_profile_report(gas_by_name: dict[str, int], components: list[Component]) -> None:
    lines = [
        "# Namespace Profile Gas Benchmarks",
        "",
        "Profiles measure direct module calls and supporting baselines. They are useful for spotting hot modules and building rough estimates before adding dedicated end-to-end scenarios.",
        "",
        "Run and regenerate:",
        "",
        "```sh",
        "./scripts/generate-benchmarks.sh",
        "```",
        "",
        f"Machine-readable profile report: [`{PROFILE_JSON}`](./{PROFILE_JSON}).",
        "",
        "Profile components are also included in [`benchmarks/gas-components.tsv`](./benchmarks/gas-components.tsv) for the calculator.",
        "",
        "## Assumptions",
        "",
        f"- ETH price: `${ETH_PRICE_USD}`",
        "- USD cost formula: `gasUsed * gasPriceGwei * 1e-9 * ETH_PRICE_USD`.",
        "- Profile entries are standalone calls, not full Namespace mint transactions.",
        "- Prefer exact scenario benchmarks when one matches the target configuration.",
        "",
    ]
    append_table(lines, "Rule Function Profiles", benchmark_rows(gas_by_name, r"testBenchmark_profile_rule_", r"^testBenchmark_profile_rule_[0-9]+_"))
    append_table(lines, "Payment Function Profiles", benchmark_rows(gas_by_name, r"testBenchmark_profile_payment_", r"^testBenchmark_profile_payment_[0-9]+_"))
    append_table(lines, "Hook Function Profiles", benchmark_rows(gas_by_name, r"testBenchmark_profile_hook_", r"^testBenchmark_profile_hook_[0-9]+_"))
    lines.extend(
        [
            "## Profile Component Keys",
            "",
            "| Key | Category | Gwei used | Description |",
            "| --- | --- | ---: | --- |",
        ]
    )
    for component in components:
        if component.kind == "profile":
            lines.append(f"| `{component.key}` | {component.category} | {component.gas} | {component.description} |")
    lines.append("")
    PROFILE_REPORT.write_text("\n".join(lines))


def write_scenario_report(gas_by_name: dict[str, int], components: list[Component]) -> None:
    lines = [
        "# Namespace Scenario Gas Benchmarks",
        "",
        "Scenario benchmarks measure full activation, mint, renewal, and registry-floor flows for common Namespace configurations.",
        "",
        "Run and regenerate:",
        "",
        "```sh",
        "./scripts/generate-benchmarks.sh",
        "```",
        "",
        "## Assumptions",
        "",
        f"- ETH price: `${ETH_PRICE_USD}`",
        "- Mint scenarios are call-only and do not include post-call test assertions.",
        "- Direct registry baselines show the approximate ENSv2 floor before Namespace rule/payment/hook overhead.",
        "- Full end-to-end scenario benchmarks remain the source of truth for production configurations.",
        "",
    ]
    append_table(lines, "Activation Setup Benchmarks", benchmark_rows(gas_by_name, r"testBenchmark_activation_", r"^testBenchmark_activation_[0-9]+_pnc"))
    append_table(lines, "Call-Only Mint Benchmarks", benchmark_rows(gas_by_name, r"testBenchmark_mint_", r"^testBenchmark_mint_[0-9]+_pnc"))
    append_table(lines, "Renewal Benchmarks", benchmark_rows(gas_by_name, r"testBenchmark_renew_", r"^testBenchmark_renew_[0-9]+_"))
    append_table(lines, "Direct ENSv2 Registry Baselines", benchmark_rows(gas_by_name, r"testBenchmark_registry_", r"^testBenchmark_registry_[0-9]+_"))
    lines.extend(
        [
            "## Exact And Delta Component Keys",
            "",
            "| Key | Kind | Gwei used | Description |",
            "| --- | --- | ---: | --- |",
        ]
    )
    for component in components:
        if component.kind != "profile":
            lines.append(f"| `{component.key}` | {component.kind} | {component.gas} | {component.description} |")
    lines.extend(
        [
            "",
            "## Calculator Examples",
            "",
            "| Example | Components | Estimated gas | USD @ 1 gwei |",
            "| --- | --- | ---: | ---: |",
        ]
    )
    component_gas = {component.key: component.gas for component in components}
    examples = [
        ("Free mint floor", ["mint.free_no_rules"]),
        ("Fixed ERC20 sale estimate", ["mint.free_no_rules", "delta.fixed_erc20_sale"]),
        ("Common three-rule ERC20 sale", ["mint.three_rules_erc20"]),
        ("Three-rule sale plus resolver writes", ["mint.three_rules_split_two_resolver_writes"]),
        ("All-rule split sale", ["mint.all_rules_split"]),
        ("All-rule split sale plus resolver writes", ["mint.all_rules_split", "delta.batch_resolver_three_writes"]),
    ]
    for label, keys in examples:
        total = sum(component_gas[key] for key in keys)
        lines.append(f"| {label} | `{' '.join(keys)}` | {total} | ${usd(total):.6f} |")
    lines.append("")
    SCENARIO_REPORT.write_text("\n".join(lines))


def write_index() -> None:
    BENCHMARK_INDEX.write_text(
        "\n".join(
            [
                "# Namespace Gas Benchmarks",
                "",
                "Benchmark output is split into focused reports:",
                "",
                "1. [Profile Gas Benchmarks](./PROFILE_BENCHMARKS.md) - direct rule, payment, and hook profile calls plus machine-readable profile JSON.",
                "2. [Scenario Gas Benchmarks](./SCENARIO_BENCHMARKS.md) - activation, mint, renewal, direct registry, exact scenario, and delta benchmarks.",
                "",
                "Regenerate all benchmark artifacts:",
                "",
                "```sh",
                "./scripts/generate-benchmarks.sh",
                "```",
                "",
                "Calculator inputs:",
                "",
                "- [`benchmarks/gas-components.tsv`](./benchmarks/gas-components.tsv)",
                "- [`benchmarks/profile-gas-report.json`](./benchmarks/profile-gas-report.json)",
                "",
            ]
        )
    )


def main() -> None:
    gas_by_name = parse_snapshot(SNAPSHOT)
    components = build_components(gas_by_name)
    write_components_tsv(components)
    write_profile_json(components)
    write_profile_report(gas_by_name, components)
    write_scenario_report(gas_by_name, components)
    write_index()


if __name__ == "__main__":
    main()
