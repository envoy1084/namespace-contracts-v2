// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceBenchmarkScenarios} from "test/benchmarks/common/NamespaceBenchmarkScenarios.sol";

/// @notice Generic PnC config builder for activation and mint gas benchmark permutations.
abstract contract NamespaceBenchmarkCombinations is NamespaceBenchmarkScenarios {
    enum PaymentMode {
        NONE,
        ERC20,
        SPLIT
    }

    enum HookMode {
        NONE,
        RECORDING,
        BATCH_RESOLVER
    }

    struct ComboSpec {
        bool pause;
        bool saleWindow;
        bool labelLength;
        bool whitelist;
        bool fixedPrice;
        bool labelClassNumber;
        bool usdOracle;
        bool lengthPremium;
        bool tokenBalance;
        bool reservation;
        uint8 fixedLengthPrices;
        uint8 premiumBuckets;
        uint16 whitelistSetSize;
        uint16 reservationSetSize;
        PaymentMode paymentMode;
        HookMode hookMode;
        uint8 resolverWrites;
    }

    function _comboSpec(uint8 preset, PaymentMode paymentMode, HookMode hookMode, uint8 resolverWrites)
        internal
        pure
        returns (ComboSpec memory spec)
    {
        spec.paymentMode = paymentMode;
        spec.hookMode = hookMode;
        spec.resolverWrites = resolverWrites;
        spec.whitelistSetSize = 10;
        spec.reservationSetSize = 10;
        spec.premiumBuckets = 5;

        if (preset == 0) return spec;
        if (preset == 1) {
            spec.saleWindow = true;
        } else if (preset == 2) {
            spec.fixedPrice = true;
        } else if (preset == 3) {
            spec.saleWindow = true;
            spec.labelLength = true;
        } else if (preset == 4) {
            spec.saleWindow = true;
            spec.fixedPrice = true;
        } else if (preset == 5) {
            spec.labelLength = true;
            spec.fixedPrice = true;
        } else if (preset == 6) {
            spec.saleWindow = true;
            spec.labelLength = true;
            spec.fixedPrice = true;
        } else if (preset == 7) {
            spec.saleWindow = true;
            spec.fixedPrice = true;
            spec.lengthPremium = true;
        } else if (preset == 8) {
            spec.saleWindow = true;
            spec.labelLength = true;
            spec.fixedPrice = true;
            spec.lengthPremium = true;
        } else if (preset == 9) {
            spec.saleWindow = true;
            spec.labelLength = true;
            spec.whitelist = true;
            spec.fixedPrice = true;
        } else if (preset == 10) {
            spec.saleWindow = true;
            spec.labelLength = true;
            spec.fixedPrice = true;
            spec.tokenBalance = true;
        } else if (preset == 11) {
            spec.saleWindow = true;
            spec.labelLength = true;
            spec.whitelist = true;
            spec.fixedPrice = true;
            spec.lengthPremium = true;
        } else if (preset == 12) {
            spec.saleWindow = true;
            spec.labelLength = true;
            spec.fixedPrice = true;
            spec.tokenBalance = true;
            spec.reservation = true;
        } else if (preset == 13) {
            spec.pause = true;
            spec.saleWindow = true;
            spec.labelLength = true;
            spec.whitelist = true;
            spec.fixedPrice = true;
            spec.reservation = true;
        } else if (preset == 14) {
            spec.saleWindow = true;
            spec.labelLength = true;
            spec.whitelist = true;
            spec.fixedPrice = true;
            spec.tokenBalance = true;
            spec.reservation = true;
        } else {
            spec.pause = true;
            spec.saleWindow = true;
            spec.labelLength = true;
            spec.whitelist = true;
            spec.fixedPrice = true;
            spec.labelClassNumber = true;
            spec.usdOracle = true;
            spec.lengthPremium = true;
            spec.tokenBalance = true;
            spec.reservation = true;
            spec.fixedLengthPrices = 3;
            spec.premiumBuckets = 12;
            spec.whitelistSetSize = 1000;
            spec.reservationSetSize = 1000;
        }
    }

    function _comboConfig(string memory label, ComboSpec memory spec)
        internal
        view
        returns (NamespaceTypes.ActivationConfig memory config)
    {
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](_comboRuleCount(spec));
        uint256 index;
        if (spec.pause) rules[index++] = _pauseConfig();
        if (spec.saleWindow) rules[index++] = _saleWindowConfig();
        if (spec.labelLength) rules[index++] = _labelLengthConfig();
        if (spec.whitelist) rules[index++] = _whitelistConfig(label, spec.whitelistSetSize);
        if (spec.fixedPrice) rules[index++] = _fixedPriceConfig(spec.fixedLengthPrices);
        if (spec.labelClassNumber) rules[index++] = _labelClassNumberConfig();
        if (spec.usdOracle) rules[index++] = _usdOracleConfig();
        if (spec.lengthPremium) rules[index++] = _lengthPremiumConfig(spec.premiumBuckets);
        if (spec.tokenBalance) rules[index++] = _tokenBalanceConfig();
        if (spec.reservation) rules[index++] = _reservationConfig(label, spec.reservationSetSize);

        NamespaceTypes.ModuleConfig[] memory postHooks = _comboPostHooks(spec);
        config = _activationConfig(rules, _comboPaymentModule(spec.paymentMode), postHooks, _comboResolver(spec));
    }

    function _comboRuntimeData(string memory label, ComboSpec memory spec)
        internal
        view
        returns (NamespaceTypes.RuntimeData memory runtimeData)
    {
        runtimeData = _runtimeData(_comboRuleCount(spec), _comboPostHookCount(spec));
        uint256 index;
        if (spec.pause) ++index;
        if (spec.saleWindow) ++index;
        if (spec.labelLength) ++index;
        if (spec.whitelist) runtimeData.ruleData[index++] = abi.encode(_whitelistClaim(label, spec.whitelistSetSize));
        if (spec.fixedPrice) ++index;
        if (spec.labelClassNumber) ++index;
        if (spec.usdOracle) ++index;
        if (spec.lengthPremium) ++index;
        if (spec.tokenBalance) ++index;
        if (spec.reservation) {
            runtimeData.ruleData[index++] = abi.encode(_reservationClaim(label, spec.reservationSetSize));
        }

        if (spec.hookMode == HookMode.RECORDING) {
            runtimeData.postHookData[0] = hex"1234";
        } else if (spec.hookMode == HookMode.BATCH_RESOLVER) {
            runtimeData.postHookData[0] = _packedResolverOverrides(spec.resolverWrites);
        }
    }

    function _comboRuleCount(ComboSpec memory spec) internal pure returns (uint256 count) {
        if (spec.pause) ++count;
        if (spec.saleWindow) ++count;
        if (spec.labelLength) ++count;
        if (spec.whitelist) ++count;
        if (spec.fixedPrice) ++count;
        if (spec.labelClassNumber) ++count;
        if (spec.usdOracle) ++count;
        if (spec.lengthPremium) ++count;
        if (spec.tokenBalance) ++count;
        if (spec.reservation) ++count;
    }

    function _comboPaymentModule(PaymentMode paymentMode)
        private
        view
        returns (NamespaceTypes.ModuleConfig memory paymentModule)
    {
        if (paymentMode == PaymentMode.ERC20) return _erc20PaymentModule();
        if (paymentMode == PaymentMode.SPLIT) return _splitPaymentModule();
        return _noPaymentModule();
    }

    function _comboPostHooks(ComboSpec memory spec)
        private
        view
        returns (NamespaceTypes.ModuleConfig[] memory postHooks)
    {
        uint256 count = _comboPostHookCount(spec);
        postHooks = count == 0 ? _noHooks() : new NamespaceTypes.ModuleConfig[](1);
        if (count == 0) return postHooks;
        address hook = spec.hookMode == HookMode.RECORDING ? address(postHook) : address(batchResolverHook);
        postHooks[0] = NamespaceTypes.ModuleConfig({module: hook, configData: ""});
    }

    function _comboPostHookCount(ComboSpec memory spec) private pure returns (uint256) {
        return spec.hookMode == HookMode.NONE ? 0 : 1;
    }

    function _comboResolver(ComboSpec memory spec) private view returns (address) {
        if (spec.hookMode == HookMode.RECORDING) return address(0xBEEF);
        if (spec.hookMode == HookMode.BATCH_RESOLVER) return address(resolver);
        return address(0);
    }
}
