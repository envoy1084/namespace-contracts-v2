// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceBenchmarkBase} from "test/benchmarks/common/NamespaceBenchmarkBase.sol";

/// @notice Activation gas profiles for individual modules used by the calculator.
contract NamespaceActivationProfileGasBenchmarks is NamespaceBenchmarkBase {
    string private constant LABEL = "12345";

    function testBenchmark_profile_activation_rule_00_pause() public benchmarkSetup {
        _activateSingleRule(_pauseConfig());
    }

    function testBenchmark_profile_activation_rule_01_saleWindow() public benchmarkSetup {
        _activateSingleRule(_saleWindowConfig());
    }

    function testBenchmark_profile_activation_rule_02_labelLength() public benchmarkSetup {
        _activateSingleRule(_labelLengthConfig());
    }

    function testBenchmark_profile_activation_rule_03_fixedPriceNoLengthOverrides() public benchmarkSetup {
        _activateSingleRule(_fixedPriceConfig(0));
    }

    function testBenchmark_profile_activation_rule_04_fixedPriceFiveOverrides() public benchmarkSetup {
        _activateSingleRule(_fixedPriceConfig(5));
    }

    function testBenchmark_profile_activation_rule_05_fixedPriceTwentyOverrides() public benchmarkSetup {
        _activateSingleRule(_fixedPriceConfig(20));
    }

    function testBenchmark_profile_activation_rule_06_lengthPremiumFiveBuckets() public benchmarkSetup {
        _activateSingleRule(_lengthPremiumConfig(5));
    }

    function testBenchmark_profile_activation_rule_07_lengthPremiumTwentyBuckets() public benchmarkSetup {
        _activateSingleRule(_lengthPremiumConfig(20));
    }

    function testBenchmark_profile_activation_rule_08_tokenBalanceDiscount() public benchmarkSetup {
        _activateSingleRule(_tokenBalanceConfig());
    }

    function testBenchmark_profile_activation_rule_09_reservation10() public benchmarkSetup {
        _activateSingleRule(_reservationConfig(LABEL, 10));
    }

    function testBenchmark_profile_activation_rule_10_reservation1000() public benchmarkSetup {
        _activateSingleRule(_reservationConfig(LABEL, 1000));
    }

    function testBenchmark_profile_activation_rule_11_whitelist10() public benchmarkSetup {
        _activateSingleRule(_whitelistConfig(LABEL, 10));
    }

    function testBenchmark_profile_activation_rule_12_whitelist1000() public benchmarkSetup {
        _activateSingleRule(_whitelistConfig(LABEL, 1000));
    }

    function testBenchmark_profile_activation_rule_13_labelClassNumber() public benchmarkSetup {
        _activateSingleRule(_labelClassNumberConfig());
    }

    function testBenchmark_profile_activation_rule_14_usdOracle() public benchmarkSetup {
        _activateSingleRule(_usdOracleConfig());
    }

    function testBenchmark_profile_activation_payment_00_erc20() public benchmarkSetup {
        _meteredActivateExistingNamespace(
            _activationConfig(new NamespaceTypes.RuleConfig[](0), _erc20PaymentModule(), _noHooks(), address(0))
        );
    }

    function testBenchmark_profile_activation_payment_01_split2() public benchmarkSetup {
        _meteredActivateExistingNamespace(
            _activationConfig(new NamespaceTypes.RuleConfig[](0), _splitPaymentModule(), _noHooks(), address(0))
        );
    }

    function testBenchmark_profile_activation_hook_00_recording() public benchmarkSetup {
        NamespaceTypes.ModuleConfig[] memory postHooks = new NamespaceTypes.ModuleConfig[](1);
        postHooks[0] = NamespaceTypes.ModuleConfig({module: address(postHook), configData: ""});
        _meteredActivateExistingNamespace(
            _activationConfig(new NamespaceTypes.RuleConfig[](0), _noPaymentModule(), postHooks, address(0xBEEF))
        );
    }

    function testBenchmark_profile_activation_hook_01_batchResolver() public benchmarkSetup {
        NamespaceTypes.ModuleConfig[] memory postHooks = new NamespaceTypes.ModuleConfig[](1);
        postHooks[0] = NamespaceTypes.ModuleConfig({module: address(batchResolverHook), configData: ""});
        _meteredActivateExistingNamespace(
            _activationConfig(new NamespaceTypes.RuleConfig[](0), _noPaymentModule(), postHooks, address(resolver))
        );
    }

    function _activateSingleRule(NamespaceTypes.RuleConfig memory rule) private {
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](1);
        rules[0] = rule;
        _meteredActivateExistingNamespace(_activationConfig(rules, _noPaymentModule(), _noHooks(), address(0)));
    }
}
