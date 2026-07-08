// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRuleModule} from "src/interfaces/IRuleModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceBenchmarkProfiles} from "test/benchmarks/common/NamespaceBenchmarkProfiles.sol";

/// @notice Direct rule-call gas profiles for each rule shape and proof size.
contract NamespaceRuleProfileGasBenchmarks is NamespaceBenchmarkProfiles {
    function testBenchmark_profile_rule_00_pause_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(pauseRule, profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_01_saleWindowOpen_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(saleWindowRule, profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_02_saleWindowBounded_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(saleWindowRule, _mintCtx(profileSaleWindowBoundedId, "profile"), "");
    }

    function testBenchmark_profile_rule_03_labelLength_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(labelLengthRule, profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_04_fixedPriceNoLengthOverrides_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(fixedPriceRule, profileDefaultMintCtx, "");
    }

    function testBenchmark_profile_rule_05_fixedPriceFiveOverridesFallback_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(fixedPriceRule, _mintCtx(profileFixedLength5Id, "profile"), "");
    }

    function testBenchmark_profile_rule_06_fixedPriceFiveOverridesExact_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(fixedPriceRule, _mintCtx(profileFixedLength5Id, "abcde"), "");
    }

    function testBenchmark_profile_rule_07_fixedPriceTwentyOverridesExact_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(fixedPriceRule, _mintCtx(profileFixedLength20Id, "profile"), "");
    }

    function testBenchmark_profile_rule_08_lengthPremiumFiveBuckets_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(lengthPremiumRule, _mintCtx(profileLengthPremium5Id, "abc"), "");
    }

    function testBenchmark_profile_rule_09_lengthPremiumFiveBucketsFallback_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(lengthPremiumRule, _mintCtx(profileLengthPremium5Id, "profile"), "");
    }

    function testBenchmark_profile_rule_10_lengthPremiumTwentyBuckets_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(lengthPremiumRule, _mintCtx(profileLengthPremium20Id, "profile"), "");
    }

    function testBenchmark_profile_rule_11_tokenBalanceDiscount_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(tokenBalanceRule, profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_12_reservation10_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(reservationRule, _mintCtx(profileReservation10Id, "profile"), reservationProof10);
    }

    function testBenchmark_profile_rule_13_reservation100_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(reservationRule, _mintCtx(profileReservation100Id, "profile"), reservationProof100);
    }

    function testBenchmark_profile_rule_14_reservation1000_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(reservationRule, _mintCtx(profileReservation1000Id, "profile"), reservationProof1000);
    }

    function testBenchmark_profile_rule_15_whitelist10_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(whitelistRule, _mintCtx(profileWhitelist10Id, "profile"), whitelistProof10);
    }

    function testBenchmark_profile_rule_16_whitelist100_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(whitelistRule, _mintCtx(profileWhitelist100Id, "profile"), whitelistProof100);
    }

    function testBenchmark_profile_rule_17_whitelist1000_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(whitelistRule, _mintCtx(profileWhitelist1000Id, "profile"), whitelistProof1000);
    }

    function testBenchmark_profile_rule_18_labelClassNumber_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(labelClassRule, _mintCtx(profileLabelClassNumberId, "12345"), "");
    }

    function testBenchmark_profile_rule_19_labelClassLetter_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(labelClassRule, _mintCtx(profileLabelClassLetterId, "profile"), "");
    }

    function testBenchmark_profile_rule_20_labelClassEmoji_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(labelClassRule, _mintCtx(profileLabelClassEmojiId, _emojiLabel()), "");
    }

    function testBenchmark_profile_rule_21_usdOracle_evaluateMint() public benchmarkSetup {
        _meteredEvaluateMint(usdOracleRule, _mintCtx(profileUsdOracleId, "usd"), "");
    }

    function testBenchmark_profile_rule_22_pause_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(pauseRule, profileFullStackRenewCtx, "");
    }

    function testBenchmark_profile_rule_23_saleWindowOpen_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(saleWindowRule, profileFullStackRenewCtx, "");
    }

    function testBenchmark_profile_rule_24_saleWindowBounded_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(saleWindowRule, _renewCtx(profileSaleWindowBoundedId, "profile"), "");
    }

    function testBenchmark_profile_rule_25_labelLength_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(labelLengthRule, profileFullStackRenewCtx, "");
    }

    function testBenchmark_profile_rule_26_fixedPriceNoLengthOverrides_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(fixedPriceRule, profileDefaultRenewCtx, "");
    }

    function testBenchmark_profile_rule_27_fixedPriceFiveOverridesFallback_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(fixedPriceRule, _renewCtx(profileFixedLength5Id, "profile"), "");
    }

    function testBenchmark_profile_rule_28_fixedPriceFiveOverridesExact_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(fixedPriceRule, _renewCtx(profileFixedLength5Id, "abcde"), "");
    }

    function testBenchmark_profile_rule_29_fixedPriceTwentyOverridesExact_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(fixedPriceRule, _renewCtx(profileFixedLength20Id, "profile"), "");
    }

    function testBenchmark_profile_rule_30_lengthPremiumFiveBuckets_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(lengthPremiumRule, _renewCtx(profileLengthPremium5Id, "abc"), "");
    }

    function testBenchmark_profile_rule_31_lengthPremiumFiveBucketsFallback_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(lengthPremiumRule, _renewCtx(profileLengthPremium5Id, "profile"), "");
    }

    function testBenchmark_profile_rule_32_lengthPremiumTwentyBuckets_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(lengthPremiumRule, _renewCtx(profileLengthPremium20Id, "profile"), "");
    }

    function testBenchmark_profile_rule_33_tokenBalanceDiscount_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(tokenBalanceRule, profileFullStackRenewCtx, "");
    }

    function testBenchmark_profile_rule_34_reservation10_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(reservationRule, _renewCtx(profileReservation10Id, "profile"), reservationProof10);
    }

    function testBenchmark_profile_rule_35_reservation100_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(reservationRule, _renewCtx(profileReservation100Id, "profile"), reservationProof100);
    }

    function testBenchmark_profile_rule_36_reservation1000_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(reservationRule, _renewCtx(profileReservation1000Id, "profile"), reservationProof1000);
    }

    function testBenchmark_profile_rule_37_whitelist10_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(whitelistRule, _renewCtx(profileWhitelist10Id, "profile"), "");
    }

    function testBenchmark_profile_rule_38_whitelist100_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(whitelistRule, _renewCtx(profileWhitelist100Id, "profile"), "");
    }

    function testBenchmark_profile_rule_39_whitelist1000_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(whitelistRule, _renewCtx(profileWhitelist1000Id, "profile"), "");
    }

    function testBenchmark_profile_rule_40_labelClassNumber_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(labelClassRule, _renewCtx(profileLabelClassNumberId, "12345"), "");
    }

    function testBenchmark_profile_rule_41_labelClassLetter_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(labelClassRule, _renewCtx(profileLabelClassLetterId, "profile"), "");
    }

    function testBenchmark_profile_rule_42_labelClassEmoji_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(labelClassRule, _renewCtx(profileLabelClassEmojiId, _emojiLabel()), "");
    }

    function testBenchmark_profile_rule_43_usdOracle_evaluateRenew() public benchmarkSetup {
        _meteredEvaluateRenew(usdOracleRule, _renewCtx(profileUsdOracleId, "usd"), "");
    }

    function _meteredEvaluateMint(IRuleModule rule, NamespaceTypes.MintContext memory ctx, bytes memory runtimeData)
        private
    {
        vm.resumeGasMetering();
        rule.evaluateMint(ctx, runtimeData);
        vm.pauseGasMetering();
    }

    function _meteredEvaluateRenew(IRuleModule rule, NamespaceTypes.RenewContext memory ctx, bytes memory runtimeData)
        private
    {
        vm.resumeGasMetering();
        rule.evaluateRenew(ctx, runtimeData);
        vm.pauseGasMetering();
    }

    function _emojiLabel() private pure returns (string memory) {
        return string(abi.encodePacked(hex"f09f9880"));
    }
}
