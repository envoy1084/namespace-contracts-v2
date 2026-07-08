// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceBenchmarkBase} from "test/benchmarks/common/NamespaceBenchmarkBase.sol";

/// @notice Activation setup gas for representative Namespace sale PnC configurations.
contract NamespaceActivationGasBenchmarks is NamespaceBenchmarkBase {
    function testBenchmark_activation_00_pncFreeNoRules() public benchmarkSetup {
        _meteredActivateExistingNamespace(_comboConfig("12345", _comboSpec(0, PaymentMode.NONE, HookMode.NONE, 0)));
    }

    function testBenchmark_activation_01_pncAllRulesSplitFiveResolverWrites() public benchmarkSetup {
        _meteredActivateExistingNamespace(
            _comboConfig("12345", _comboSpec(15, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 5))
        );
    }
}
