// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceBenchmarkBase} from "test/benchmarks/common/NamespaceBenchmarkBase.sol";

/// @notice Call-only mint and renewal gas through NamespaceController and ENSv2 registry.
contract NamespaceMintGasBenchmarks is NamespaceBenchmarkBase {
    MintScenario internal mintFreeNoRules;
    MintScenario internal mintAllRulesSplitFiveResolverWrites;
    MintScenario internal renewFreeNoRules;
    MintScenario internal renewAllRulesSplitFiveResolverWrites;

    function setUp() public override {
        super.setUp();

        ComboSpec memory freeSpec = _comboSpec(0, PaymentMode.NONE, HookMode.NONE, 0);
        ComboSpec memory highSpec = _comboSpec(15, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 5);

        mintFreeNoRules =
            _prepareMintScenario("free", _comboConfig("free", freeSpec), _comboRuntimeData("free", freeSpec));
        mintAllRulesSplitFiveResolverWrites =
            _prepareMintScenario("12345", _comboConfig("12345", highSpec), _comboRuntimeData("12345", highSpec));
        renewFreeNoRules = _prepareRenewScenario(
            "renewfree", _comboConfig("renewfree", freeSpec), _comboRuntimeData("renewfree", freeSpec)
        );
        renewAllRulesSplitFiveResolverWrites =
            _prepareRenewScenario("12345", _comboConfig("12345", highSpec), _comboRuntimeData("12345", highSpec));
    }

    function testBenchmark_mint_00_pncFreeNoRules() public benchmarkSetup {
        _meteredMint(mintFreeNoRules);
    }

    function testBenchmark_mint_01_pncAllRulesSplitFiveResolverWrites() public benchmarkSetup {
        _meteredMint(mintAllRulesSplitFiveResolverWrites);
    }

    function testBenchmark_renew_00_pncFreeNoRules() public benchmarkSetup {
        _meteredRenew(renewFreeNoRules, 30 days);
    }

    function testBenchmark_renew_01_pncAllRulesSplitFiveResolverWrites() public benchmarkSetup {
        _meteredRenew(renewAllRulesSplitFiveResolverWrites, 30 days);
    }
}
