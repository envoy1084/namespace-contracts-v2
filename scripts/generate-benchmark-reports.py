#!/usr/bin/env python3
"""Generate Namespace benchmark reports from a Foundry gas snapshot."""

from __future__ import annotations

import json
import os
import re
import argparse
from dataclasses import dataclass
from pathlib import Path


SNAPSHOT = Path("benchmarks/.gas-snapshot")
BENCHMARK_INDEX = Path("benchmarks/BENCHMARKS.md")
PROFILE_REPORT = Path("benchmarks/PROFILE_BENCHMARKS.md")
SCENARIO_REPORT = Path("benchmarks/SCENARIO_BENCHMARKS.md")
COMPONENTS_TSV = Path("benchmarks/gas-components.tsv")
PROFILE_JSON = Path("benchmarks/profile-gas-report.json")
ETH_PRICE_USD = int(os.environ.get("ETH_PRICE_USD", "3000"))

SNAPSHOT_LINE = re.compile(r"^[^:]+:(?P<name>[^\s]+)\(\) \(gas: (?P<gas>\d+)\)$")
SLICE_LINE = re.compile(
    r"^\s*(?P<label>(?:activation|mint|renew)\.(?:free|high)\.[A-Za-z0-9_.]+): (?P<gas>\d+)$"
)


@dataclass(frozen=True)
class Component:
    key: str
    kind: str
    source: str
    description: str
    gas: int
    activation_gas: int | None = None

    @property
    def category(self) -> str:
        return self.key.split(".", 1)[0]


@dataclass(frozen=True)
class LogicalSlice:
    key: str
    description: str
    formula: str


RULE_MINT_PROFILES = [
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
]

RULE_RENEW_PROFILES = [
    ("rule_renew.pause", "testBenchmark_profile_rule_22_pause_evaluateRenew", "PauseRule evaluateRenew."),
    ("rule_renew.sale_window_open", "testBenchmark_profile_rule_23_saleWindowOpen_evaluateRenew", "SaleWindowRule evaluateRenew with open zero-bounds config."),
    ("rule_renew.sale_window_bounded", "testBenchmark_profile_rule_24_saleWindowBounded_evaluateRenew", "SaleWindowRule evaluateRenew with active start/end bounds."),
    ("rule_renew.label_length", "testBenchmark_profile_rule_25_labelLength_evaluateRenew", "LabelLengthRule evaluateRenew."),
    ("rule_renew.fixed_price_no_overrides", "testBenchmark_profile_rule_26_fixedPriceNoLengthOverrides_evaluateRenew", "FixedPriceRule renewal with no length overrides."),
    ("rule_renew.fixed_price_5_fallback", "testBenchmark_profile_rule_27_fixedPriceFiveOverridesFallback_evaluateRenew", "FixedPriceRule renewal with five overrides and fallback label."),
    ("rule_renew.fixed_price_5_exact", "testBenchmark_profile_rule_28_fixedPriceFiveOverridesExact_evaluateRenew", "FixedPriceRule renewal with five overrides and exact-length hit."),
    ("rule_renew.fixed_price_20_exact", "testBenchmark_profile_rule_29_fixedPriceTwentyOverridesExact_evaluateRenew", "FixedPriceRule renewal with twenty overrides and exact-length hit."),
    ("rule_renew.length_premium_5", "testBenchmark_profile_rule_30_lengthPremiumFiveBuckets_evaluateRenew", "LengthPremiumRule renewal with five buckets."),
    ("rule_renew.length_premium_5_fallback", "testBenchmark_profile_rule_31_lengthPremiumFiveBucketsFallback_evaluateRenew", "LengthPremiumRule renewal with five buckets and fallback bucket."),
    ("rule_renew.length_premium_20", "testBenchmark_profile_rule_32_lengthPremiumTwentyBuckets_evaluateRenew", "LengthPremiumRule renewal with twenty buckets."),
    ("rule_renew.token_balance_discount", "testBenchmark_profile_rule_33_tokenBalanceDiscount_evaluateRenew", "TokenBalanceRule renewal with minimum balance and discount."),
    ("rule_renew.reservation_10", "testBenchmark_profile_rule_34_reservation10_evaluateRenew", "ReservationRule renewal with Merkle set size 10."),
    ("rule_renew.reservation_100", "testBenchmark_profile_rule_35_reservation100_evaluateRenew", "ReservationRule renewal with Merkle set size 100."),
    ("rule_renew.reservation_1000", "testBenchmark_profile_rule_36_reservation1000_evaluateRenew", "ReservationRule renewal with Merkle set size 1000."),
    ("rule_renew.whitelist_10", "testBenchmark_profile_rule_37_whitelist10_evaluateRenew", "WhitelistRule renewal with renew checks disabled."),
    ("rule_renew.whitelist_100", "testBenchmark_profile_rule_38_whitelist100_evaluateRenew", "WhitelistRule renewal with renew checks disabled."),
    ("rule_renew.whitelist_1000", "testBenchmark_profile_rule_39_whitelist1000_evaluateRenew", "WhitelistRule renewal with renew checks disabled."),
    ("rule_renew.label_class_number", "testBenchmark_profile_rule_40_labelClassNumber_evaluateRenew", "LabelClassRule renewal for numeric labels."),
    ("rule_renew.label_class_letter", "testBenchmark_profile_rule_41_labelClassLetter_evaluateRenew", "LabelClassRule renewal for ASCII letter labels."),
    ("rule_renew.label_class_emoji", "testBenchmark_profile_rule_42_labelClassEmoji_evaluateRenew", "LabelClassRule renewal for emoji labels."),
    ("rule_renew.usd_oracle", "testBenchmark_profile_rule_43_usdOracle_evaluateRenew", "USDOracleRule renewal with Chainlink-compatible oracle."),
]

PAYMENT_HOOK_PROFILES = [
    ("payment.erc20", "testBenchmark_profile_payment_00_collectMintERC20", "Direct ERC20 transferFrom payment module."),
    ("payment.split_2", "testBenchmark_profile_payment_01_collectMintSplitERC20TwoRecipients", "ERC20 split payment to two recipients."),
    ("payment.split_3", "testBenchmark_profile_payment_02_collectMintSplitERC20ThreeRecipients", "ERC20 split payment to three recipients."),
    ("payment.split_5", "testBenchmark_profile_payment_03_collectMintSplitERC20FiveRecipients", "ERC20 split payment to five recipients."),
    ("payment_renew.erc20", "testBenchmark_profile_payment_04_collectRenewERC20", "Direct ERC20 transferFrom renewal payment."),
    ("payment_renew.split_2", "testBenchmark_profile_payment_05_collectRenewSplitERC20TwoRecipients", "ERC20 renewal split payment to two recipients."),
    ("payment_renew.split_3", "testBenchmark_profile_payment_06_collectRenewSplitERC20ThreeRecipients", "ERC20 renewal split payment to three recipients."),
    ("payment_renew.split_5", "testBenchmark_profile_payment_07_collectRenewSplitERC20FiveRecipients", "ERC20 renewal split payment to five recipients."),
    ("hook.recording", "testBenchmark_profile_hook_00_recordingPostHook_afterMint", "Recording post-hook profile."),
    ("hook.set_addr_empty", "testBenchmark_profile_hook_01_setAddrToBuyerEmpty_afterMint", "SetAddrToBuyerHook using buyer address."),
    ("hook.set_addr_override", "testBenchmark_profile_hook_02_setAddrToBuyerOverride_afterMint", "SetAddrToBuyerHook using address override."),
    ("hook.batch_resolver_1", "testBenchmark_profile_hook_03_batchResolverHookOneWrite_afterMint", "BatchSetAddrToBuyerHook with one resolver write."),
    ("hook.batch_resolver_3", "testBenchmark_profile_hook_04_batchResolverHookThreeWrites_afterMint", "BatchSetAddrToBuyerHook with three resolver writes."),
    ("hook.batch_resolver_5", "testBenchmark_profile_hook_05_batchResolverHookFiveWrites_afterMint", "BatchSetAddrToBuyerHook with five resolver writes."),
    ("hook_renew.recording", "testBenchmark_profile_hook_06_recordingPostHook_afterRenew", "Recording post-hook afterRenew profile."),
    ("hook_renew.set_addr", "testBenchmark_profile_hook_07_setAddrToBuyer_afterRenew", "SetAddrToBuyerHook afterRenew no-op profile."),
    ("hook_renew.batch_resolver", "testBenchmark_profile_hook_08_batchResolverHook_afterRenew", "BatchSetAddrToBuyerHook afterRenew no-op profile."),
]

ACTIVATION_PROFILE_SOURCES = {
    "pause": "testBenchmark_profile_activation_rule_00_pause",
    "sale_window": "testBenchmark_profile_activation_rule_01_saleWindow",
    "label_length": "testBenchmark_profile_activation_rule_02_labelLength",
    "fixed_price_no_overrides": "testBenchmark_profile_activation_rule_03_fixedPriceNoLengthOverrides",
    "fixed_price_5": "testBenchmark_profile_activation_rule_04_fixedPriceFiveOverrides",
    "fixed_price_20": "testBenchmark_profile_activation_rule_05_fixedPriceTwentyOverrides",
    "length_premium_5": "testBenchmark_profile_activation_rule_06_lengthPremiumFiveBuckets",
    "length_premium_20": "testBenchmark_profile_activation_rule_07_lengthPremiumTwentyBuckets",
    "token_balance_discount": "testBenchmark_profile_activation_rule_08_tokenBalanceDiscount",
    "reservation_10": "testBenchmark_profile_activation_rule_09_reservation10",
    "reservation_100": "testBenchmark_profile_activation_rule_09_reservation10",
    "reservation_1000": "testBenchmark_profile_activation_rule_10_reservation1000",
    "whitelist_10": "testBenchmark_profile_activation_rule_11_whitelist10",
    "whitelist_100": "testBenchmark_profile_activation_rule_11_whitelist10",
    "whitelist_1000": "testBenchmark_profile_activation_rule_12_whitelist1000",
    "label_class_number": "testBenchmark_profile_activation_rule_13_labelClassNumber",
    "label_class_letter": "testBenchmark_profile_activation_rule_13_labelClassNumber",
    "label_class_emoji": "testBenchmark_profile_activation_rule_13_labelClassNumber",
    "usd_oracle": "testBenchmark_profile_activation_rule_14_usdOracle",
    "erc20": "testBenchmark_profile_activation_payment_00_erc20",
    "split_2": "testBenchmark_profile_activation_payment_01_split2",
    "recording": "testBenchmark_profile_activation_hook_00_recording",
    "set_addr_empty": "testBenchmark_profile_activation_hook_01_batchResolver",
    "set_addr_override": "testBenchmark_profile_activation_hook_01_batchResolver",
    "batch_resolver_1": "testBenchmark_profile_activation_hook_01_batchResolver",
    "batch_resolver_3": "testBenchmark_profile_activation_hook_01_batchResolver",
    "batch_resolver_5": "testBenchmark_profile_activation_hook_01_batchResolver",
}

SLICE_METRIC_DESCRIPTIONS = {
    "load_resolver_and_validate_name": "Load the configured Universal Resolver and reject empty ENS names.",
    "find_exact_registry": "Universal Resolver lookup for the namespace registry.",
    "find_parent_registry": "Universal Resolver lookup for the parent registry.",
    "universal_resolver_discovery": "Combined Universal Resolver registry discovery cost.",
    "label_hash_and_parent_state": "Hash the namespace label and read its parent-registry state.",
    "parent_subregistry_check": "Verify the parent registry points to the resolved namespace registry.",
    "namehash_and_activation_key": "Compute the ENS node and activation id.",
    "duration_and_payment_checks": "Validate duration bounds and payment module approval.",
    "owner_admin_check": "Confirm the name owner still has admin authority on the registry.",
    "controller_registry_roles_check": "Confirm the controller can register and renew subnames.",
    "activation_id_check": "Check that the activation id is unused.",
    "store_module_lists": "Store configured rule and hook module lists.",
    "store_activation": "Write the activation record to controller storage.",
    "store_owner_and_registries": "Activation storage sub-slice for owner, registry, and parent registry.",
    "store_namespace_identity": "Activation storage sub-slice for parent node and namespace resource id.",
    "store_namespace_label": "Activation storage sub-slice for the namespace label string.",
    "store_mint_config": "Activation storage sub-slice for resolver, roles, duration bounds, and active flag.",
    "store_module_refs": "Activation storage sub-slice for module list references and counters.",
    "emit_activation_events": "Emit activation-created and activation-status events.",
    "configure_modules": "Call configured modules so they store activation-scoped parameters.",
    "activation_load_and_active": "Load activation state and reject inactive activations.",
    "namespace_current": "Read parent registry state to ensure the namespace is still registered.",
    "duration_and_runtime_checks": "Validate requested duration and runtime data array lengths.",
    "label_hash_and_context": "Hash the subname label and construct the mint context.",
    "label_activation_store": "Map the minted label to the activation id for future renewals.",
    "label_state_and_activation_check": "Read label state and verify the label belongs to this activation.",
    "expiry_and_context": "Compute renewal expiry and construct the renewal context.",
    "evaluate_rules": "Run the configured rule modules.",
    "registry_write": "Call the official ENSv2 PermissionedRegistry.",
    "collect_payment": "Run payment collection if rules produced a non-zero price.",
    "post_hooks": "Run configured post hooks.",
    "emit_event": "Emit the mint or renewal event.",
    "measured_body_total": "Measured body total for the profiled controller function.",
}

SCENARIO_DESCRIPTIONS = {
    "free": "No-rules path",
    "high": "All-rules, split-payment, five-resolver-write path",
}


def parse_snapshot(path: Path) -> dict[str, int]:
    gas_by_name: dict[str, int] = {}
    for line in path.read_text().splitlines():
        match = SNAPSHOT_LINE.match(line.strip())
        if match:
            gas_by_name[match.group("name")] = int(match.group("gas"))
    return gas_by_name


def snake_case(value: str) -> str:
    value = value.replace(".", "_")
    value = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", value)
    return value.lower()


def parse_slice_log(path: Path | None) -> list[Component]:
    if path is None:
        return []
    if not path.exists():
        raise SystemExit(f"Missing slice log: {path}")

    components: list[Component] = []
    seen: set[str] = set()
    for line in path.read_text().splitlines():
        match = SLICE_LINE.match(line)
        if match is None:
            continue
        raw_label = match.group("label")
        domain, scenario, metric_raw = raw_label.split(".", 2)
        metric = snake_case(metric_raw)
        key = f"slice.{domain}.{scenario}.{metric}"
        if key in seen:
            continue
        seen.add(key)
        scenario_description = SCENARIO_DESCRIPTIONS.get(scenario, scenario)
        metric_description = SLICE_METRIC_DESCRIPTIONS.get(metric, humanize(metric, ""))
        description = f"{scenario_description}: {metric_description}"
        components.append(Component(key, "slice", raw_label, description, int(match.group("gas"))))

    return sorted(components, key=slice_sort_key)


def slice_sort_key(component: Component) -> tuple[int, int, int, str]:
    _, domain, scenario, metric = component.key.split(".", 3)
    domain_order = {"activation": 0, "mint": 1, "renew": 2}
    scenario_order = {"free": 0, "high": 1}
    metric_order = {
        name: index
        for index, name in enumerate(
            [
                "load_resolver_and_validate_name",
                "find_exact_registry",
                "find_parent_registry",
                "universal_resolver_discovery",
                "label_hash_and_parent_state",
                "parent_subregistry_check",
                "namehash_and_activation_key",
                "duration_and_payment_checks",
                "activation_load_and_active",
                "namespace_current",
                "owner_admin_check",
                "controller_registry_roles_check",
                "activation_id_check",
                "store_module_lists",
                "store_activation",
                "store_owner_and_registries",
                "store_namespace_identity",
                "store_namespace_label",
                "store_mint_config",
                "store_module_refs",
                "configure_modules",
                "emit_activation_events",
                "duration_and_runtime_checks",
                "label_hash_and_context",
                "label_activation_store",
                "label_state_and_activation_check",
                "expiry_and_context",
                "evaluate_rules",
                "registry_write",
                "collect_payment",
                "post_hooks",
                "emit_event",
                "measured_body_total",
            ]
        )
    }
    return (
        domain_order.get(domain, 99),
        scenario_order.get(scenario, 99),
        metric_order.get(metric, 999),
        component.key,
    )


def usd(gas: int) -> float:
    return gas * 1e-9 * ETH_PRICE_USD


def humanize(name: str, prefix: str) -> str:
    value = re.sub(prefix, "", name)
    value = value.replace("_", " ")
    out: list[str] = []
    for index, char in enumerate(value):
        previous = value[index - 1] if index else ""
        if char.isupper() and (previous.islower() or previous.isdigit()):
            out.append(" ")
        out.append(char)
    return "".join(out)


def add_component(
    components: list[Component],
    gas_by_name: dict[str, int],
    key: str,
    kind: str,
    source: str,
    description: str,
    activation_source: str | None = None,
) -> None:
    activation_gas = None
    if activation_source is not None:
        activation_gas = gas_by_name[activation_source] - gas_by_name["testBenchmark_activation_00_pncFreeNoRules"]
    components.append(Component(key, kind, source, description, gas_by_name[source], activation_gas))


def add_delta(
    components: list[Component],
    gas_by_name: dict[str, int],
    key: str,
    source: str,
    base: str,
    description: str,
) -> None:
    components.append(Component(key, "delta", f"{source} - {base}", description, gas_by_name[source] - gas_by_name[base]))


def activation_profile_source(key: str) -> str | None:
    suffix = key.split(".", 1)[1]
    suffix = suffix.removesuffix("_fallback").removesuffix("_exact")
    if suffix.startswith("sale_window"):
        suffix = "sale_window"
    elif suffix.startswith("fixed_price_5"):
        suffix = "fixed_price_5"
    elif suffix.startswith("fixed_price_20"):
        suffix = "fixed_price_20"
    elif suffix.startswith("length_premium_5"):
        suffix = "length_premium_5"
    elif suffix.startswith("length_premium_20"):
        suffix = "length_premium_20"
    return ACTIVATION_PROFILE_SOURCES.get(suffix)


def build_components(gas_by_name: dict[str, int], slice_components: list[Component]) -> list[Component]:
    components: list[Component] = []

    exacts = [
        ("activation.free_no_rules", "testBenchmark_activation_00_pncFreeNoRules", "Activation with no rules, no payment, no hooks."),
        ("activation.all_rules_split_five_resolver_writes", "testBenchmark_activation_01_pncAllRulesSplitFiveResolverWrites", "Activation with every current rule, split payment, and five resolver writes."),
        ("mint.free_no_rules", "testBenchmark_mint_00_pncFreeNoRules", "Controller mint with no rules, no payment, no hooks."),
        ("mint.all_rules_split_five_resolver_writes", "testBenchmark_mint_01_pncAllRulesSplitFiveResolverWrites", "Controller mint with every current rule, split payment, and five resolver writes."),
        ("renew.free_no_rules", "testBenchmark_renew_00_pncFreeNoRules", "Controller renewal with no rules, no payment, no hooks."),
        ("renew.all_rules_split_five_resolver_writes", "testBenchmark_renew_01_pncAllRulesSplitFiveResolverWrites", "Controller renewal with every current rule, split payment, and five resolver writes."),
    ]
    for key, source, description in exacts:
        add_component(components, gas_by_name, key, "exact", source, description)

    floors = [
        ("registry.register_no_roles", "testBenchmark_registry_00_registerNoRolesNoResolver", "Direct ENSv2 registry register with owner, no buyer roles, no resolver."),
        ("registry.register_buyer_roles", "testBenchmark_registry_01_registerBuyerRolesNoResolver", "Direct ENSv2 registry register with buyer roles and no resolver."),
        ("registry.register_buyer_roles_resolver", "testBenchmark_registry_02_registerBuyerRolesWithResolver", "Direct ENSv2 registry register with buyer roles and resolver."),
        ("registry.reserve_no_owner", "testBenchmark_registry_03_reserveLabelNoOwner", "Direct ENSv2 registry reserve flow with owner set to zero."),
        ("registry.renew_registered", "testBenchmark_registry_04_renewRegistered", "Direct ENSv2 registry renewal baseline."),
    ]
    for key, source, description in floors:
        add_component(components, gas_by_name, key, "floor", source, description)

    for key, source, description in [*RULE_MINT_PROFILES, *RULE_RENEW_PROFILES, *PAYMENT_HOOK_PROFILES]:
        add_component(components, gas_by_name, key, "profile", source, description, activation_profile_source(key))

    components.extend(slice_components)

    add_delta(
        components,
        gas_by_name,
        "delta.activation_all_rules_high",
        "testBenchmark_activation_01_pncAllRulesSplitFiveResolverWrites",
        "testBenchmark_activation_00_pncFreeNoRules",
        "Incremental activation setup cost from every current rule, split payment, and five resolver writes.",
    )
    add_delta(
        components,
        gas_by_name,
        "delta.mint_all_rules_high",
        "testBenchmark_mint_01_pncAllRulesSplitFiveResolverWrites",
        "testBenchmark_mint_00_pncFreeNoRules",
        "Incremental mint cost from every current rule, split payment, and five resolver writes.",
    )
    add_delta(
        components,
        gas_by_name,
        "delta.renew_all_rules_high",
        "testBenchmark_renew_01_pncAllRulesSplitFiveResolverWrites",
        "testBenchmark_renew_00_pncFreeNoRules",
        "Incremental renewal cost from every current rule, split payment, and five resolver writes.",
    )
    return components


def component_json(component: Component) -> dict[str, str | int]:
    data: dict[str, str | int] = {
        "category": component.category,
        "kind": component.kind,
        "gas": component.gas,
        "source": component.source,
        "description": component.description,
    }
    if component.activation_gas is not None:
        data["activationGas"] = component.activation_gas
    return data


def logical_slice_json(row: LogicalSlice) -> dict[str, str | int]:
    return {
        "description": row.description,
        "formula": row.formula,
    }


def append_component_table(lines: list[str], title: str, components: list[Component]) -> None:
    if not components:
        return
    lines.extend(
        [
            f"## {title}",
            "",
            "| Key | Description | Gas used | USD @ 1 gwei |",
            "| --- | --- | ---: | ---: |",
        ]
    )
    for component in components:
        lines.append(f"| `{component.key}` | {component.description} | {component.gas} | ${usd(component.gas):.6f} |")
    lines.append("")


def append_logical_slice_table(lines: list[str], title: str, rows: list[LogicalSlice]) -> None:
    if not rows:
        return
    lines.extend(
        [
            f"## {title}",
            "",
            "| Key | Logical slice | Gas formula / driver |",
            "| --- | --- | --- |",
        ]
    )
    for row in rows:
        lines.append(f"| `{row.key}` | {row.description} | {row.formula} |")
    lines.append("")


def components_by_key(components: list[Component]) -> dict[str, Component]:
    return {component.key: component for component in components}


def selected_components(components: list[Component], keys: list[str]) -> list[Component]:
    by_key = components_by_key(components)
    return [by_key[key] for key in keys if key in by_key]


def category_components(components: list[Component], categories: set[str]) -> list[Component]:
    return [component for component in components if component.category in categories and component.kind == "profile"]


def logical_activation_slices(components: list[Component]) -> list[LogicalSlice]:
    return [
        LogicalSlice(
            key="slice.activation.namespace_discovery",
            description="Resolve and prove the ENSv2 namespace registry for the activated name.",
            formula="~42.7k fixed for `alice.eth`; varies with name depth and Universal Resolver implementation.",
        ),
        LogicalSlice(
            key="slice.activation.precondition_checks",
            description="Validate duration bounds, payment module approval, owner admin, controller roles, and unused activation id.",
            formula="~12.1k + ~4.7k * `has_payment_module`.",
        ),
        LogicalSlice(
            key="slice.activation.store_module_lists",
            description="Persist configured rule and post-hook module references.",
            formula="~0.6k if empty; if `rule_count > 1`, about ~0.6k + ~11.4k * `rule_count`; if `post_hook_count > 1`, add the packed hook-list SSTORE2 write.",
        ),
        LogicalSlice(
            key="slice.activation.store_activation_record",
            description="Write activation owner, registries, namespace identity, label, resolver, bounds, payment, and module refs.",
            formula="~186k + ~19.9k * `has_resolver` + ~19.9k * `has_payment_or_module_refs`.",
        ),
        LogicalSlice(
            key="slice.activation.configure_modules",
            description="Call modules so they store activation-scoped params.",
            formula="~0.8k + sum(`configure(rule_i)`) + `configure(payment_module)` if set + sum(`configure(hook_i)`).",
        ),
    ]


def logical_mint_slices(components: list[Component]) -> list[LogicalSlice]:
    return [
        LogicalSlice(
            key="slice.mint.activation_and_namespace_checks",
            description="Load activation, check active status, prove namespace currentness, owner admin, duration, and runtime data lengths.",
            formula="~34.1k fixed per mint.",
        ),
        LogicalSlice(
            key="slice.mint.label_context_and_tracking",
            description="Hash label, construct MintContext, and store label -> activation id for renewal checks.",
            formula="~29.8k fixed per newly minted label.",
        ),
        LogicalSlice(
            key="slice.mint.rule_engine",
            description="Evaluate configured rule modules and apply price effects in phase order.",
            formula="~0.5k if `rule_count = 0`; otherwise SSTORE2 read when `rule_count > 1` + sum(`evaluateMint(rule_i, runtimeData_i)`) + output checks. Merkle rules add roughly ~2.5k * `proof_depth` inside that rule.",
        ),
        LogicalSlice(
            key="slice.mint.registry_register",
            description="Call official ENSv2 PermissionedRegistry.register.",
            formula="~105k-156k per mint depending buyer roles and resolver write path.",
        ),
        LogicalSlice(
            key="slice.mint.payment_collection",
            description="Collect payment if the final rule price is nonzero.",
            formula="~0.3k if free; direct ERC20 ~85k; split ERC20 ~= ~45.8k + ~30k * `payment_recipients`.",
        ),
        LogicalSlice(
            key="slice.mint.post_hooks",
            description="Run configured post-mint hooks.",
            formula="~0.4k if `post_hook_count = 0`; otherwise sum(`afterMint(hook_i)`). Batch resolver hook ~= ~77.7k + ~9.7k * `resolver_writes`.",
        ),
    ]


def logical_renew_slices(components: list[Component]) -> list[LogicalSlice]:
    return [
        LogicalSlice(
            key="slice.renew.activation_and_namespace_checks",
            description="Load activation, check active status, prove namespace currentness, owner admin, duration, and runtime data lengths.",
            formula="~34.1k fixed per renewal.",
        ),
        LogicalSlice(
            key="slice.renew.label_state_and_context",
            description="Read label state, verify activation ownership, compute new expiry, and construct RenewContext.",
            formula="~14.2k fixed per renewal.",
        ),
        LogicalSlice(
            key="slice.renew.rule_engine",
            description="Evaluate configured renewal rule modules and apply price effects in phase order.",
            formula="~0.5k if `rule_count = 0`; otherwise SSTORE2 read when `rule_count > 1` + sum(`evaluateRenew(rule_i, runtimeData_i)`) + output checks. Merkle renewal rules add roughly ~2.5k * `proof_depth` when enabled.",
        ),
        LogicalSlice(
            key="slice.renew.registry_renew",
            description="Call official ENSv2 PermissionedRegistry.renew.",
            formula="~15.2k fixed when the registry state is warm in the controller flow.",
        ),
        LogicalSlice(
            key="slice.renew.payment_collection",
            description="Collect renewal payment if the final rule price is nonzero.",
            formula="~0.3k if free; direct ERC20 ~81k; split ERC20 ~= ~43.5k + ~30k * `payment_recipients`.",
        ),
        LogicalSlice(
            key="slice.renew.post_hooks",
            description="Run configured post-renew hooks.",
            formula="~0.4k if `post_hook_count = 0`; otherwise sum(`afterRenew(hook_i)`). Current resolver hooks are no-op on renew, so most cost is hook dispatch.",
        ),
    ]


def write_components_tsv(components: list[Component]) -> None:
    COMPONENTS_TSV.parent.mkdir(parents=True, exist_ok=True)
    lines = ["key\tkind\tgas\tsource\tdescription\tactivationGas"]
    for component in components:
        activation_gas = "n/a" if component.activation_gas is None else str(component.activation_gas)
        lines.append(
            f"{component.key}\t{component.kind}\t{component.gas}\t{component.source}\t{component.description}\t{activation_gas}"
        )
    COMPONENTS_TSV.write_text("\n".join(lines) + "\n")


def write_profile_json(components: list[Component]) -> None:
    exact = {component.key: component for component in components if component.kind in {"exact", "floor"}}
    profiles = {component.key: component for component in components if component.kind == "profile"}
    slices = {component.key: component for component in components if component.kind == "slice"}
    deltas = {component.key: component for component in components if component.kind == "delta"}
    data = {
        "schemaVersion": 2,
        "source": str(SNAPSHOT),
        "ethPriceUsd": ETH_PRICE_USD,
        "estimator": {
            "mintBaseKey": "mint.free_no_rules",
            "renewBaseKey": "renew.free_no_rules",
            "activationBaseKey": "activation.free_no_rules",
            "componentCatalog": str(COMPONENTS_TSV),
            "notes": [
                "Profile entries are standalone module-call measurements.",
                "Use exact scenario keys when they match a production configuration.",
                "Use slice profile tests with forge -vv for per-slice logs.",
            ],
        },
        "profiles": {key: component_json(component) for key, component in profiles.items()},
        "slices": {key: component_json(component) for key, component in slices.items()},
        "logicalSlices": {
            row.key: logical_slice_json(row)
            for row in [
                *logical_activation_slices(components),
                *logical_mint_slices(components),
                *logical_renew_slices(components),
            ]
        },
        "exact": {key: component_json(component) for key, component in exact.items()},
        "deltas": {key: component_json(component) for key, component in deltas.items()},
    }
    PROFILE_JSON.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def write_profile_report(components: list[Component]) -> None:
    lines = [
        "# Namespace Profile Gas Benchmarks",
        "",
        "Profiles measure direct module calls and controller slice probes. Use this report to find which rules, payments, hooks, and controller steps consume the most gas.",
        "",
        "Run and regenerate:",
        "",
        "```sh",
        "./scripts/generate-benchmarks.sh",
        "```",
        "",
        "Run slice profiles with logs:",
        "",
        "```sh",
        "forge test --match-contract 'Namespace(Activation|Runtime)SliceProfile' -vv",
        "```",
        "",
        f"- ETH price: `${ETH_PRICE_USD}`",
        "- USD cost formula: `gasUsed * gasPriceGwei * 1e-9 * ETH_PRICE_USD`.",
        "- Profile benchmark wrappers pause Foundry gas metering around setup/context construction and resume only for the target module call.",
        "- Profile entries are standalone calls, not full Namespace transactions.",
        "- Slice model rows focus on dominant costs; small fixed overhead such as events and residual control flow is intentionally omitted.",
        "- Variable legend: `rule_count` is configured rule modules, `post_hook_count` is configured hooks, `payment_recipients` is split-payment recipients, `resolver_writes` is packed resolver writes, and `proof_depth = ceil(log2(set_size))` for Merkle rules.",
        "",
    ]
    append_component_table(lines, "Rule Function Profiles", category_components(components, {"rule", "rule_renew"}))
    append_component_table(
        lines, "Payment Function Profiles", category_components(components, {"payment", "payment_renew"})
    )
    append_component_table(lines, "Hook Function Profiles", category_components(components, {"hook", "hook_renew"}))
    append_logical_slice_table(lines, "Activation Logical Slice Model", logical_activation_slices(components))
    append_logical_slice_table(lines, "Mint Logical Slice Model", logical_mint_slices(components))
    append_logical_slice_table(lines, "Renew Logical Slice Model", logical_renew_slices(components))
    PROFILE_REPORT.write_text("\n".join(lines))


def write_scenario_report(components: list[Component]) -> None:
    lines = [
        "# Namespace Scenario Gas Benchmarks",
        "",
        "Scenario benchmarks are intentionally limited to the lowest-cost and highest-cost PnC configurations.",
        "",
        f"- ETH price: `${ETH_PRICE_USD}`",
        "- Benchmark wrappers pause Foundry gas metering around setup/config construction and resume only for the target external call.",
        "- Activation benchmarks exclude prerequisite ENSv2 namespace registry deployment.",
        "- Mint and renewal scenarios are call-only and do not include post-call test assertions.",
        "- Foundry execution gas does not include transaction intrinsic gas or calldata byte gas charged by the network.",
        "",
    ]
    append_component_table(
        lines,
        "Activation Setup Benchmarks",
        selected_components(
            components,
            ["activation.free_no_rules", "activation.all_rules_split_five_resolver_writes"],
        ),
    )
    append_component_table(
        lines,
        "Call-Only Mint Benchmarks",
        selected_components(components, ["mint.free_no_rules", "mint.all_rules_split_five_resolver_writes"]),
    )
    append_component_table(
        lines,
        "Renewal Benchmarks",
        selected_components(components, ["renew.free_no_rules", "renew.all_rules_split_five_resolver_writes"]),
    )
    append_component_table(
        lines,
        "Direct ENSv2 Registry Baselines",
        selected_components(
            components,
            [
                "registry.register_no_roles",
                "registry.register_buyer_roles",
                "registry.register_buyer_roles_resolver",
                "registry.reserve_no_owner",
                "registry.renew_registered",
            ],
        ),
    )
    SCENARIO_REPORT.write_text("\n".join(lines))


def write_index() -> None:
    BENCHMARK_INDEX.write_text(
        "\n".join(
            [
                "# Namespace Gas Benchmarks",
                "",
                "Benchmark output is split into focused reports:",
                "",
                "1. [Profile Gas Benchmarks](./PROFILE_BENCHMARKS.md) - rule, payment, hook, and logical controller slice gas models.",
                "2. [Scenario Gas Benchmarks](./SCENARIO_BENCHMARKS.md) - low/high activation, mint, renewal, and direct registry baselines.",
                "",
                "Regenerate all benchmark artifacts:",
                "",
                "```sh",
                "./scripts/generate-benchmarks.sh",
                "```",
                "",
                "Interactive gas calculator:",
                "",
                "```sh",
                "./scripts/calculate-gas.py interactive",
                "```",
                "",
            ]
        )
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--slice-log", type=Path, help="forge -vv output from Namespace slice profile tests")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    gas_by_name = parse_snapshot(SNAPSHOT)
    components = build_components(gas_by_name, parse_slice_log(args.slice_log))
    write_components_tsv(components)
    write_profile_json(components)
    write_profile_report(components)
    write_scenario_report(components)
    write_index()


if __name__ == "__main__":
    main()
