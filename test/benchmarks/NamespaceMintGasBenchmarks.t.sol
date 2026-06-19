// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceBenchmarkBase} from "test/benchmarks/common/NamespaceBenchmarkBase.sol";

/// @notice End-to-end mint and renewal gas through NamespaceController and ENSv2 registry.
contract NamespaceMintGasBenchmarks is NamespaceBenchmarkBase {
    MintScenario[25] internal mintPnc;
    MintScenario internal renewThreeRulesERC20;

    function setUp() public override {
        super.setUp();

        _storeMintPnc(0, 0, PaymentMode.NONE, HookMode.NONE, 0);
        _storeMintPnc(1, 1, PaymentMode.NONE, HookMode.NONE, 0);
        _storeMintPnc(2, 2, PaymentMode.ERC20, HookMode.NONE, 0);
        _storeMintPnc(3, 2, PaymentMode.SPLIT, HookMode.NONE, 0);
        _storeMintPnc(4, 3, PaymentMode.NONE, HookMode.NONE, 0);
        _storeMintPnc(5, 4, PaymentMode.ERC20, HookMode.NONE, 0);
        _storeMintPnc(6, 4, PaymentMode.SPLIT, HookMode.NONE, 0);
        _storeMintPnc(7, 5, PaymentMode.ERC20, HookMode.NONE, 0);
        _storeMintPnc(8, 6, PaymentMode.ERC20, HookMode.NONE, 0);
        _storeMintPnc(9, 6, PaymentMode.SPLIT, HookMode.NONE, 0);
        _storeMintPnc(10, 6, PaymentMode.ERC20, HookMode.RECORDING, 0);
        _storeMintPnc(11, 6, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 2);
        _storeMintPnc(12, 7, PaymentMode.ERC20, HookMode.NONE, 0);
        _storeMintPnc(13, 7, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 3);
        _storeMintPnc(14, 9, PaymentMode.ERC20, HookMode.NONE, 0);
        _storeMintPnc(15, 9, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 2);
        _storeMintPnc(16, 8, PaymentMode.ERC20, HookMode.NONE, 0);
        _storeMintPnc(17, 8, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 3);
        _storeMintPnc(18, 11, PaymentMode.SPLIT, HookMode.NONE, 0);
        _storeMintPnc(19, 12, PaymentMode.SPLIT, HookMode.NONE, 0);
        _storeMintPnc(20, 13, PaymentMode.SPLIT, HookMode.NONE, 0);
        _storeMintPnc(21, 14, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 3);
        _storeMintPnc(22, 15, PaymentMode.SPLIT, HookMode.NONE, 0);
        _storeMintPnc(23, 15, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 3);
        _storeMintPnc(24, 15, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 5);

        renewThreeRulesERC20 = _prepareRenewScenario("renewal", _threeRulesConfig(false, false), _runtimeData(3, 0));
    }

    function testBenchmark_mint_00_pncFreeNoRules() public {
        _mint(mintPnc[0]);
    }

    function testBenchmark_mint_01_pncOneGuardRuleFree() public {
        _mint(mintPnc[1]);
    }

    function testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment() public {
        _mint(mintPnc[2]);
    }

    function testBenchmark_mint_03_pncOneFixedPriceRuleSplitPayment() public {
        _mint(mintPnc[3]);
    }

    function testBenchmark_mint_04_pncTwoRulesFreeNoResolver() public {
        _mint(mintPnc[4]);
    }

    function testBenchmark_mint_05_pncTwoRulesERC20PaymentNoResolver() public {
        _mint(mintPnc[5]);
    }

    function testBenchmark_mint_06_pncTwoRulesSplitPaymentNoResolver() public {
        _mint(mintPnc[6]);
    }

    function testBenchmark_mint_07_pncTwoEligibilityPriceRulesERC20Payment() public {
        _mint(mintPnc[7]);
    }

    function testBenchmark_mint_08_pncThreeRulesERC20PaymentNoResolver() public {
        _mint(mintPnc[8]);
    }

    function testBenchmark_mint_09_pncThreeRulesSplitPaymentNoResolver() public {
        _mint(mintPnc[9]);
    }

    function testBenchmark_mint_10_pncThreeRulesERC20PaymentRecordingHook() public {
        _mint(mintPnc[10]);
    }

    function testBenchmark_mint_11_pncThreeRulesSplitPaymentTwoResolverWrites() public {
        _mint(mintPnc[11]);
    }

    function testBenchmark_mint_12_pncThreeRulesPremiumERC20PaymentNoResolver() public {
        _mint(mintPnc[12]);
    }

    function testBenchmark_mint_13_pncThreeRulesPremiumSplitPaymentThreeResolverWrites() public {
        _mint(mintPnc[13]);
    }

    function testBenchmark_mint_14_pncFourRulesWhitelistERC20PaymentNoResolver() public {
        _mint(mintPnc[14]);
    }

    function testBenchmark_mint_15_pncFourRulesWhitelistSplitPaymentTwoResolverWrites() public {
        _mint(mintPnc[15]);
    }

    function testBenchmark_mint_16_pncFourRulesPremiumERC20PaymentNoResolver() public {
        _mint(mintPnc[16]);
    }

    function testBenchmark_mint_17_pncFourRulesPremiumSplitPaymentThreeResolverWrites() public {
        _mint(mintPnc[17]);
    }

    function testBenchmark_mint_18_pncFiveRulesWhitelistPremiumSplitNoResolver() public {
        _mint(mintPnc[18]);
    }

    function testBenchmark_mint_19_pncFiveRulesReservationDiscountSplitNoResolver() public {
        _mint(mintPnc[19]);
    }

    function testBenchmark_mint_20_pncSixRulesPauseWhitelistReservationSplitNoResolver() public {
        _mint(mintPnc[20]);
    }

    function testBenchmark_mint_21_pncSixRulesWhitelistReservationSplitThreeResolverWrites() public {
        _mint(mintPnc[21]);
    }

    function testBenchmark_mint_22_pncAllRulesSplitNoResolverWrites() public {
        _mint(mintPnc[22]);
    }

    function testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites() public {
        _mint(mintPnc[23]);
    }

    function testBenchmark_mint_24_pncAllRulesSplitFiveResolverWrites() public {
        _mint(mintPnc[24]);
    }

    function testBenchmark_renew_00_threeRulesERC20PaymentNoHook() public {
        vm.prank(accounts.buyer.addr);
        controller.renew(renewThreeRulesERC20.activationId, renewThreeRulesERC20.label, 30 days, _runtimeData(3, 0));
    }

    function _storeMintPnc(
        uint256 index,
        uint8 preset,
        PaymentMode paymentMode,
        HookMode hookMode,
        uint8 resolverWrites
    ) private {
        mintPnc[index] = _prepareComboScenario(preset, paymentMode, hookMode, resolverWrites);
    }
}
