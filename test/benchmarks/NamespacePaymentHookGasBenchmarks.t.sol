// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPaymentModule} from "src/interfaces/IPaymentModule.sol";
import {IPostHookModule} from "src/interfaces/IPostHookModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceBenchmarkProfiles} from "test/benchmarks/common/NamespaceBenchmarkProfiles.sol";

/// @notice Direct payment and post-hook profiles used by the gas calculator.
contract NamespacePaymentHookGasBenchmarks is NamespaceBenchmarkProfiles {
    function testBenchmark_profile_payment_00_collectMintERC20() public benchmarkSetup {
        _meteredCollectMint(erc20Payment, profileDefaultMintCtx, profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_01_collectMintSplitERC20TwoRecipients() public benchmarkSetup {
        _meteredCollectMint(splitPayment, _mintCtx(profileSplit2Id, "profile"), profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_02_collectMintSplitERC20ThreeRecipients() public benchmarkSetup {
        _meteredCollectMint(splitPayment, _mintCtx(profileSplit3Id, "profile"), profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_03_collectMintSplitERC20FiveRecipients() public benchmarkSetup {
        _meteredCollectMint(splitPayment, _mintCtx(profileSplit5Id, "profile"), profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_04_collectRenewERC20() public benchmarkSetup {
        _meteredCollectRenew(erc20Payment, profileDefaultRenewCtx, profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_05_collectRenewSplitERC20TwoRecipients() public benchmarkSetup {
        _meteredCollectRenew(splitPayment, _renewCtx(profileSplit2Id, "profile"), profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_06_collectRenewSplitERC20ThreeRecipients() public benchmarkSetup {
        _meteredCollectRenew(splitPayment, _renewCtx(profileSplit3Id, "profile"), profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_07_collectRenewSplitERC20FiveRecipients() public benchmarkSetup {
        _meteredCollectRenew(splitPayment, _renewCtx(profileSplit5Id, "profile"), profileTokenPrice, "");
    }

    function testBenchmark_profile_hook_00_recordingPostHook_afterMint() public benchmarkSetup {
        _meteredAfterMint(postHook, profileDefaultMintCtx, 1, "");
    }

    function testBenchmark_profile_hook_01_setAddrToBuyerEmpty_afterMint() public benchmarkSetup {
        _meteredAfterMint(setAddrHook, profileSetAddrMintCtx, 1, "");
    }

    function testBenchmark_profile_hook_02_setAddrToBuyerOverride_afterMint() public benchmarkSetup {
        _meteredAfterMint(setAddrHook, profileSetAddrMintCtx, 1, setAddrOverride);
    }

    function testBenchmark_profile_hook_03_batchResolverHookOneWrite_afterMint() public benchmarkSetup {
        _meteredAfterMint(batchResolverHook, profileFullStackMintCtx, 1, oneResolverWrite);
    }

    function testBenchmark_profile_hook_04_batchResolverHookThreeWrites_afterMint() public benchmarkSetup {
        _meteredAfterMint(batchResolverHook, profileFullStackMintCtx, 1, threeResolverWrites);
    }

    function testBenchmark_profile_hook_05_batchResolverHookFiveWrites_afterMint() public benchmarkSetup {
        _meteredAfterMint(batchResolverHook, profileFullStackMintCtx, 1, fiveResolverWrites);
    }

    function testBenchmark_profile_hook_06_recordingPostHook_afterRenew() public benchmarkSetup {
        _meteredAfterRenew(postHook, profileDefaultRenewCtx, "");
    }

    function testBenchmark_profile_hook_07_setAddrToBuyer_afterRenew() public benchmarkSetup {
        _meteredAfterRenew(setAddrHook, profileSetAddrRenewCtx, "");
    }

    function testBenchmark_profile_hook_08_batchResolverHook_afterRenew() public benchmarkSetup {
        _meteredAfterRenew(batchResolverHook, profileFullStackRenewCtx, fiveResolverWrites);
    }

    function _meteredCollectMint(
        IPaymentModule payment,
        NamespaceTypes.MintContext memory ctx,
        NamespaceTypes.Price memory price,
        bytes memory runtimeData
    ) private {
        vm.prank(address(controller));
        vm.resumeGasMetering();
        payment.collectMint(ctx, price, runtimeData);
        vm.pauseGasMetering();
    }

    function _meteredCollectRenew(
        IPaymentModule payment,
        NamespaceTypes.RenewContext memory ctx,
        NamespaceTypes.Price memory price,
        bytes memory runtimeData
    ) private {
        vm.prank(address(controller));
        vm.resumeGasMetering();
        payment.collectRenew(ctx, price, runtimeData);
        vm.pauseGasMetering();
    }

    function _meteredAfterMint(
        IPostHookModule hook,
        NamespaceTypes.MintContext memory ctx,
        uint256 tokenId,
        bytes memory runtimeData
    ) private {
        vm.prank(address(controller));
        vm.resumeGasMetering();
        hook.afterMint(ctx, tokenId, runtimeData);
        vm.pauseGasMetering();
    }

    function _meteredAfterRenew(IPostHookModule hook, NamespaceTypes.RenewContext memory ctx, bytes memory runtimeData)
        private
    {
        vm.prank(address(controller));
        vm.resumeGasMetering();
        hook.afterRenew(ctx, runtimeData);
        vm.pauseGasMetering();
    }
}
