// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAggregatorV3} from "src/interfaces/IAggregatorV3.sol";
import {LabelClassRule} from "src/modules/rules/LabelClassRule.sol";
import {ReservationRule} from "src/modules/rules/ReservationRule.sol";
import {USDOracleRule} from "src/modules/rules/USDOracleRule.sol";
import {WhitelistRule} from "src/modules/rules/WhitelistRule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceBenchmarkBase} from "test/benchmarks/common/NamespaceBenchmarkBase.sol";

/// @notice Direct module profiles for estimating per-component gas in arbitrary configurations.
contract NamespaceModuleGasBenchmarks is NamespaceBenchmarkBase {
    bytes internal reservationProof10;
    bytes internal reservationProof1000;
    bytes internal whitelistProof10;
    bytes internal whitelistProof1000;
    bytes internal threeResolverWrites;
    bytes internal fiveResolverWrites;
    bytes32 internal profileReservation10Id;
    bytes32 internal profileReservation1000Id;
    bytes32 internal profileWhitelist10Id;
    bytes32 internal profileWhitelist1000Id;
    bytes32 internal profileFixedLength5Id;
    bytes32 internal profileFixedLength20Id;
    bytes32 internal profileLengthPremium5Id;
    bytes32 internal profileLengthPremium20Id;
    bytes32 internal profileLabelClassId;
    bytes32 internal profileUsdOracleId;
    NamespaceTypes.MintContext internal profileDefaultMintCtx;
    NamespaceTypes.MintContext internal profileFullStackMintCtx;
    NamespaceTypes.Price internal profileTokenPrice;

    function setUp() public override {
        super.setUp();

        MintScenario memory defaultScenario =
            _prepareMintScenario("default", _threeRulesConfig(false, false), _runtimeData(3, 0));
        MintScenario memory fullStackScenario = _prepareMintScenario(
            "12345", _allRulesConfig("12345", 1000, 1000, 5), _allRulesRuntimeData("12345", 1000, 1000, 5)
        );

        reservationProof10 = abi.encode(_reservationClaim("profile", 10));
        reservationProof1000 = abi.encode(_reservationClaim("profile", 1000));
        whitelistProof10 = abi.encode(_whitelistClaim("profile", 10));
        whitelistProof1000 = abi.encode(_whitelistClaim("profile", 1000));
        threeResolverWrites = _packedResolverOverrides(3);
        fiveResolverWrites = _packedResolverOverrides(5);
        _configureProfileRules();
        profileDefaultMintCtx = _mintCtx(defaultScenario.activationId, "default");
        profileFullStackMintCtx = _mintCtx(fullStackScenario.activationId, "12345");
        profileTokenPrice = NamespaceTypes.Price({token: address(token), amount: 100 ether});
    }

    function testBenchmark_profile_rule_00_pause_evaluateMint() public view {
        pauseRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_01_saleWindow_evaluateMint() public view {
        saleWindowRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_02_labelLength_evaluateMint() public view {
        labelLengthRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_03_fixedPriceNoLengthOverrides_evaluateMint() public view {
        fixedPriceRule.evaluateMint(profileDefaultMintCtx, "");
    }

    function testBenchmark_profile_rule_04_fixedPriceFiveLengthOverrides_evaluateMint() public view {
        fixedPriceRule.evaluateMint(_mintCtx(profileFixedLength5Id, "profile"), "");
    }

    function testBenchmark_profile_rule_05_fixedPriceTwentyLengthOverrides_evaluateMint() public view {
        fixedPriceRule.evaluateMint(_mintCtx(profileFixedLength20Id, "profile"), "");
    }

    function testBenchmark_profile_rule_06_lengthPremiumFiveBuckets_evaluateMint() public view {
        lengthPremiumRule.evaluateMint(_mintCtx(profileLengthPremium5Id, "profile"), "");
    }

    function testBenchmark_profile_rule_07_lengthPremiumTwentyBuckets_evaluateMint() public view {
        lengthPremiumRule.evaluateMint(_mintCtx(profileLengthPremium20Id, "profile"), "");
    }

    function testBenchmark_profile_rule_08_tokenBalanceDiscount_evaluateMint() public view {
        tokenBalanceRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_09_reservation10_evaluateMint() public view {
        reservationRule.evaluateMint(_mintCtx(profileReservation10Id, "profile"), reservationProof10);
    }

    function testBenchmark_profile_rule_10_reservation1000_evaluateMint() public view {
        reservationRule.evaluateMint(_mintCtx(profileReservation1000Id, "profile"), reservationProof1000);
    }

    function testBenchmark_profile_rule_11_whitelist10_evaluateMint() public view {
        whitelistRule.evaluateMint(_mintCtx(profileWhitelist10Id, "profile"), whitelistProof10);
    }

    function testBenchmark_profile_rule_12_whitelist1000_evaluateMint() public view {
        whitelistRule.evaluateMint(_mintCtx(profileWhitelist1000Id, "profile"), whitelistProof1000);
    }

    function testBenchmark_profile_rule_13_labelClassNumber_evaluateMint() public view {
        labelClassRule.evaluateMint(_mintCtx(profileLabelClassId, "12345"), "");
    }

    function testBenchmark_profile_rule_14_usdOracle_evaluateMint() public view {
        usdOracleRule.evaluateMint(_mintCtx(profileUsdOracleId, "usd"), "");
    }

    function testBenchmark_profile_payment_00_collectMintERC20() public {
        vm.prank(address(controller));
        erc20Payment.collectMint(profileDefaultMintCtx, profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_01_collectMintSplitERC20() public {
        vm.prank(address(controller));
        splitPayment.collectMint(profileFullStackMintCtx, profileTokenPrice, "");
    }

    function testBenchmark_profile_hook_00_recordingPostHook_afterMint() public {
        vm.prank(address(controller));
        postHook.afterMint(profileDefaultMintCtx, 1, "");
    }

    function testBenchmark_profile_hook_01_batchResolverHookThreeWrites_afterMint() public {
        vm.prank(address(controller));
        batchResolverHook.afterMint(profileFullStackMintCtx, 1, threeResolverWrites);
    }

    function testBenchmark_profile_hook_02_batchResolverHookFiveWrites_afterMint() public {
        vm.prank(address(controller));
        batchResolverHook.afterMint(profileFullStackMintCtx, 1, fiveResolverWrites);
    }

    function _configureProfileRules() private {
        profileReservation10Id = keccak256(abi.encode("profile-reservation", uint256(10)));
        profileReservation1000Id = keccak256(abi.encode("profile-reservation", uint256(1000)));
        profileWhitelist10Id = keccak256(abi.encode("profile-whitelist", uint256(10)));
        profileWhitelist1000Id = keccak256(abi.encode("profile-whitelist", uint256(1000)));
        profileFixedLength5Id = keccak256(abi.encode("profile-fixed-length", uint256(5)));
        profileFixedLength20Id = keccak256(abi.encode("profile-fixed-length", uint256(20)));
        profileLengthPremium5Id = keccak256(abi.encode("profile-length-premium", uint256(5)));
        profileLengthPremium20Id = keccak256(abi.encode("profile-length-premium", uint256(20)));
        profileLabelClassId = keccak256("profile-label-class");
        profileUsdOracleId = keccak256("profile-usd-oracle");

        vm.startPrank(address(controller));
        reservationRule.configure(
            profileReservation10Id,
            abi.encode(
                ReservationRule.Params({root: _rootFor(reservationRule.leaf(_reservationClaim("profile", 10)), 10)})
            )
        );
        reservationRule.configure(
            profileReservation1000Id,
            abi.encode(
                ReservationRule.Params({root: _rootFor(reservationRule.leaf(_reservationClaim("profile", 1000)), 1000)})
            )
        );
        whitelistRule.configure(
            profileWhitelist10Id,
            abi.encode(
                WhitelistRule.Params({
                    mintRoot: _rootFor(whitelistRule.leaf(_whitelistClaim("profile", 10)), 10), renewRoot: bytes32(0)
                })
            )
        );
        whitelistRule.configure(
            profileWhitelist1000Id,
            abi.encode(
                WhitelistRule.Params({
                    mintRoot: _rootFor(whitelistRule.leaf(_whitelistClaim("profile", 1000)), 1000),
                    renewRoot: bytes32(0)
                })
            )
        );
        fixedPriceRule.configure(profileFixedLength5Id, abi.encode(_fixedPriceParams(5)));
        fixedPriceRule.configure(profileFixedLength20Id, abi.encode(_fixedPriceParams(20)));
        lengthPremiumRule.configure(profileLengthPremium5Id, abi.encode(_lengthPremiumParams(5)));
        lengthPremiumRule.configure(profileLengthPremium20Id, abi.encode(_lengthPremiumParams(20)));
        labelClassRule.configure(profileLabelClassId, abi.encode(_labelClassNumberParams()));
        usdOracleRule.configure(profileUsdOracleId, abi.encode(_usdOracleParams()));
        vm.stopPrank();
    }

    function _labelClassNumberParams() private view returns (LabelClassRule.Params memory params) {
        params = LabelClassRule.Params({
            token: address(token),
            labelClass: LabelClassRule.LabelClass.NUMBER,
            requireMatch: true,
            mintAmount: 10 ether,
            renewAmount: 5 ether,
            priceOp: NamespaceTypes.PriceOp.ADD
        });
    }

    function _usdOracleParams() private view returns (USDOracleRule.Params memory params) {
        params = USDOracleRule.Params({
            token: address(token),
            oracle: IAggregatorV3(address(oracle)),
            tokenDecimals: 18,
            maxStaleness: 1 days,
            mintUsdPrice: 100e18,
            renewUsdPrice: 25e18,
            priceOp: NamespaceTypes.PriceOp.ADD
        });
    }
}
