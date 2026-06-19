// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceBenchmarkBase} from "test/benchmarks/common/NamespaceBenchmarkBase.sol";

/// @notice Activation setup gas for representative Namespace sale PnC configurations.
contract NamespaceActivationGasBenchmarks is NamespaceBenchmarkBase {
    function testBenchmark_activation_00_pncFreeNoRules() public {
        _activateCombo(0, PaymentMode.NONE, HookMode.NONE, 0);
    }

    function testBenchmark_activation_01_pncOneGuardRuleFree() public {
        _activateCombo(1, PaymentMode.NONE, HookMode.NONE, 0);
    }

    function testBenchmark_activation_02_pncOneFixedPriceRuleERC20Payment() public {
        _activateCombo(2, PaymentMode.ERC20, HookMode.NONE, 0);
    }

    function testBenchmark_activation_03_pncOneFixedPriceRuleSplitPayment() public {
        _activateCombo(2, PaymentMode.SPLIT, HookMode.NONE, 0);
    }

    function testBenchmark_activation_04_pncTwoRulesFreeNoResolver() public {
        _activateCombo(3, PaymentMode.NONE, HookMode.NONE, 0);
    }

    function testBenchmark_activation_05_pncTwoRulesERC20PaymentNoResolver() public {
        _activateCombo(4, PaymentMode.ERC20, HookMode.NONE, 0);
    }

    function testBenchmark_activation_06_pncTwoRulesSplitPaymentNoResolver() public {
        _activateCombo(4, PaymentMode.SPLIT, HookMode.NONE, 0);
    }

    function testBenchmark_activation_07_pncTwoEligibilityPriceRulesERC20Payment() public {
        _activateCombo(5, PaymentMode.ERC20, HookMode.NONE, 0);
    }

    function testBenchmark_activation_08_pncThreeRulesERC20PaymentNoResolver() public {
        _activateCombo(6, PaymentMode.ERC20, HookMode.NONE, 0);
    }

    function testBenchmark_activation_09_pncThreeRulesSplitPaymentNoResolver() public {
        _activateCombo(6, PaymentMode.SPLIT, HookMode.NONE, 0);
    }

    function testBenchmark_activation_10_pncThreeRulesERC20PaymentRecordingHook() public {
        _activateCombo(6, PaymentMode.ERC20, HookMode.RECORDING, 0);
    }

    function testBenchmark_activation_11_pncThreeRulesSplitPaymentTwoResolverWrites() public {
        _activateCombo(6, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 2);
    }

    function testBenchmark_activation_12_pncThreeRulesPremiumERC20PaymentNoResolver() public {
        _activateCombo(7, PaymentMode.ERC20, HookMode.NONE, 0);
    }

    function testBenchmark_activation_13_pncThreeRulesPremiumSplitPaymentThreeResolverWrites() public {
        _activateCombo(7, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 3);
    }

    function testBenchmark_activation_14_pncFourRulesWhitelistERC20PaymentNoResolver() public {
        _activateCombo(9, PaymentMode.ERC20, HookMode.NONE, 0);
    }

    function testBenchmark_activation_15_pncFourRulesWhitelistSplitPaymentTwoResolverWrites() public {
        _activateCombo(9, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 2);
    }

    function testBenchmark_activation_16_pncFourRulesPremiumERC20PaymentNoResolver() public {
        _activateCombo(8, PaymentMode.ERC20, HookMode.NONE, 0);
    }

    function testBenchmark_activation_17_pncFourRulesPremiumSplitPaymentThreeResolverWrites() public {
        _activateCombo(8, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 3);
    }

    function testBenchmark_activation_18_pncFiveRulesWhitelistPremiumSplitNoResolver() public {
        _activateCombo(11, PaymentMode.SPLIT, HookMode.NONE, 0);
    }

    function testBenchmark_activation_19_pncFiveRulesReservationDiscountSplitNoResolver() public {
        _activateCombo(12, PaymentMode.SPLIT, HookMode.NONE, 0);
    }

    function testBenchmark_activation_20_pncSixRulesPauseWhitelistReservationSplitNoResolver() public {
        _activateCombo(13, PaymentMode.SPLIT, HookMode.NONE, 0);
    }

    function testBenchmark_activation_21_pncSixRulesWhitelistReservationSplitThreeResolverWrites() public {
        _activateCombo(14, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 3);
    }

    function testBenchmark_activation_22_pncAllRulesSplitNoResolverWrites() public {
        _activateCombo(15, PaymentMode.SPLIT, HookMode.NONE, 0);
    }

    function testBenchmark_activation_23_pncAllRulesSplitThreeResolverWrites() public {
        _activateCombo(15, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 3);
    }

    function testBenchmark_activation_24_pncAllRulesSplitFiveResolverWrites() public {
        _activateCombo(15, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 5);
    }
}
