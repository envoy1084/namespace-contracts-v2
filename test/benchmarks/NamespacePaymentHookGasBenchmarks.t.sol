// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceBenchmarkProfiles} from "test/benchmarks/common/NamespaceBenchmarkProfiles.sol";

/// @notice Direct payment and post-hook profiles used by the gas calculator.
contract NamespacePaymentHookGasBenchmarks is NamespaceBenchmarkProfiles {
    function testBenchmark_profile_payment_00_collectMintERC20() public {
        vm.prank(address(controller));
        erc20Payment.collectMint(profileDefaultMintCtx, profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_01_collectMintSplitERC20TwoRecipients() public {
        vm.prank(address(controller));
        splitPayment.collectMint(_mintCtx(profileSplit2Id, "profile"), profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_02_collectMintSplitERC20ThreeRecipients() public {
        vm.prank(address(controller));
        splitPayment.collectMint(_mintCtx(profileSplit3Id, "profile"), profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_03_collectMintSplitERC20FiveRecipients() public {
        vm.prank(address(controller));
        splitPayment.collectMint(_mintCtx(profileSplit5Id, "profile"), profileTokenPrice, "");
    }

    function testBenchmark_profile_hook_00_recordingPostHook_afterMint() public {
        vm.prank(address(controller));
        postHook.afterMint(profileDefaultMintCtx, 1, "");
    }

    function testBenchmark_profile_hook_01_setAddrToBuyerEmpty_afterMint() public {
        vm.prank(address(controller));
        setAddrHook.afterMint(profileSetAddrMintCtx, 1, "");
    }

    function testBenchmark_profile_hook_02_setAddrToBuyerOverride_afterMint() public {
        vm.prank(address(controller));
        setAddrHook.afterMint(profileSetAddrMintCtx, 1, setAddrOverride);
    }

    function testBenchmark_profile_hook_03_batchResolverHookOneWrite_afterMint() public {
        vm.prank(address(controller));
        batchResolverHook.afterMint(profileFullStackMintCtx, 1, oneResolverWrite);
    }

    function testBenchmark_profile_hook_04_batchResolverHookThreeWrites_afterMint() public {
        vm.prank(address(controller));
        batchResolverHook.afterMint(profileFullStackMintCtx, 1, threeResolverWrites);
    }

    function testBenchmark_profile_hook_05_batchResolverHookFiveWrites_afterMint() public {
        vm.prank(address(controller));
        batchResolverHook.afterMint(profileFullStackMintCtx, 1, fiveResolverWrites);
    }
}
