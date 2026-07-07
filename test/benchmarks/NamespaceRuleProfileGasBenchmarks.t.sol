// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceBenchmarkProfiles} from "test/benchmarks/common/NamespaceBenchmarkProfiles.sol";

/// @notice Direct rule-call gas profiles for each rule shape and proof size.
contract NamespaceRuleProfileGasBenchmarks is NamespaceBenchmarkProfiles {
    function testBenchmark_profile_rule_00_pause_evaluateMint() public view {
        pauseRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_01_saleWindowOpen_evaluateMint() public view {
        saleWindowRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_02_saleWindowBounded_evaluateMint() public view {
        saleWindowRule.evaluateMint(_mintCtx(profileSaleWindowBoundedId, "profile"), "");
    }

    function testBenchmark_profile_rule_03_labelLength_evaluateMint() public view {
        labelLengthRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_04_fixedPriceNoLengthOverrides_evaluateMint() public view {
        fixedPriceRule.evaluateMint(profileDefaultMintCtx, "");
    }

    function testBenchmark_profile_rule_05_fixedPriceFiveOverridesFallback_evaluateMint() public view {
        fixedPriceRule.evaluateMint(_mintCtx(profileFixedLength5Id, "profile"), "");
    }

    function testBenchmark_profile_rule_06_fixedPriceFiveOverridesExact_evaluateMint() public view {
        fixedPriceRule.evaluateMint(_mintCtx(profileFixedLength5Id, "abcde"), "");
    }

    function testBenchmark_profile_rule_07_fixedPriceTwentyOverridesExact_evaluateMint() public view {
        fixedPriceRule.evaluateMint(_mintCtx(profileFixedLength20Id, "profile"), "");
    }

    function testBenchmark_profile_rule_08_lengthPremiumFiveBuckets_evaluateMint() public view {
        lengthPremiumRule.evaluateMint(_mintCtx(profileLengthPremium5Id, "abc"), "");
    }

    function testBenchmark_profile_rule_09_lengthPremiumFiveBucketsFallback_evaluateMint() public view {
        lengthPremiumRule.evaluateMint(_mintCtx(profileLengthPremium5Id, "profile"), "");
    }

    function testBenchmark_profile_rule_10_lengthPremiumTwentyBuckets_evaluateMint() public view {
        lengthPremiumRule.evaluateMint(_mintCtx(profileLengthPremium20Id, "profile"), "");
    }

    function testBenchmark_profile_rule_11_tokenBalanceDiscount_evaluateMint() public view {
        tokenBalanceRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_12_reservation10_evaluateMint() public view {
        reservationRule.evaluateMint(_mintCtx(profileReservation10Id, "profile"), reservationProof10);
    }

    function testBenchmark_profile_rule_13_reservation100_evaluateMint() public view {
        reservationRule.evaluateMint(_mintCtx(profileReservation100Id, "profile"), reservationProof100);
    }

    function testBenchmark_profile_rule_14_reservation1000_evaluateMint() public view {
        reservationRule.evaluateMint(_mintCtx(profileReservation1000Id, "profile"), reservationProof1000);
    }

    function testBenchmark_profile_rule_15_whitelist10_evaluateMint() public view {
        whitelistRule.evaluateMint(_mintCtx(profileWhitelist10Id, "profile"), whitelistProof10);
    }

    function testBenchmark_profile_rule_16_whitelist100_evaluateMint() public view {
        whitelistRule.evaluateMint(_mintCtx(profileWhitelist100Id, "profile"), whitelistProof100);
    }

    function testBenchmark_profile_rule_17_whitelist1000_evaluateMint() public view {
        whitelistRule.evaluateMint(_mintCtx(profileWhitelist1000Id, "profile"), whitelistProof1000);
    }

    function testBenchmark_profile_rule_18_labelClassNumber_evaluateMint() public view {
        labelClassRule.evaluateMint(_mintCtx(profileLabelClassNumberId, "12345"), "");
    }

    function testBenchmark_profile_rule_19_labelClassLetter_evaluateMint() public view {
        labelClassRule.evaluateMint(_mintCtx(profileLabelClassLetterId, "profile"), "");
    }

    function testBenchmark_profile_rule_20_labelClassEmoji_evaluateMint() public view {
        labelClassRule.evaluateMint(_mintCtx(profileLabelClassEmojiId, _emojiLabel()), "");
    }

    function testBenchmark_profile_rule_21_usdOracle_evaluateMint() public view {
        usdOracleRule.evaluateMint(_mintCtx(profileUsdOracleId, "usd"), "");
    }

    function _emojiLabel() private pure returns (string memory) {
        return string(abi.encodePacked(hex"f09f9880"));
    }
}
