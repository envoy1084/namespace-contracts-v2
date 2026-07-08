// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceBenchmarkCombinations} from "test/benchmarks/common/NamespaceBenchmarkCombinations.sol";

/// @notice Small base entry point used by concrete gas benchmark suites.
abstract contract NamespaceBenchmarkBase is NamespaceBenchmarkCombinations {
    uint256 private benchmarkNamespaceCounter;

    modifier benchmarkSetup() {
        vm.pauseGasMetering();
        _;
    }

    struct MintScenario {
        bytes32 activationId;
        string label;
        NamespaceTypes.RuntimeData runtimeData;
    }

    function _prepareMintScenario(
        string memory label,
        NamespaceTypes.ActivationConfig memory config,
        NamespaceTypes.RuntimeData memory runtimeData
    ) internal returns (MintScenario memory scenario) {
        scenario.activationId = _activate(config);
        vm.prank(accounts.buyer.addr);
        try tokenBalanceRule.recordBalance(scenario.activationId) {
            vm.warp(block.timestamp + 1);
        } catch {}
        scenario.label = label;
        scenario.runtimeData = runtimeData;
    }

    function _prepareRenewScenario(
        string memory label,
        NamespaceTypes.ActivationConfig memory config,
        NamespaceTypes.RuntimeData memory runtimeData
    ) internal returns (MintScenario memory scenario) {
        scenario = _prepareMintScenario(label, config, runtimeData);
        _mint(scenario);
    }

    function _prepareComboScenario(uint8 preset, PaymentMode paymentMode, HookMode hookMode, uint8 resolverWrites)
        internal
        returns (MintScenario memory scenario)
    {
        string memory label = "12345";
        ComboSpec memory spec = _comboSpec(preset, paymentMode, hookMode, resolverWrites);
        scenario = _prepareMintScenario(label, _comboConfig(label, spec), _comboRuntimeData(label, spec));
    }

    function _activateCombo(uint8 preset, PaymentMode paymentMode, HookMode hookMode, uint8 resolverWrites) internal {
        string memory label = "12345";
        ComboSpec memory spec = _comboSpec(preset, paymentMode, hookMode, resolverWrites);
        _activateExistingNamespace(_comboConfig(label, spec));
    }

    function _activate(NamespaceTypes.ActivationConfig memory config) internal returns (bytes32 activationId) {
        unchecked {
            ++benchmarkNamespaceCounter;
        }
        activationId = _activateNamespace(string.concat("bench", vm.toString(benchmarkNamespaceCounter)), config);
    }

    function _activateExistingNamespace(NamespaceTypes.ActivationConfig memory config)
        internal
        returns (bytes32 activationId)
    {
        vm.prank(accounts.alice.addr);
        activationId = controller.activate(_aliceName(), config);
    }

    function _meteredActivateExistingNamespace(NamespaceTypes.ActivationConfig memory config)
        internal
        returns (bytes32 activationId)
    {
        bytes memory name = _aliceName();
        vm.prank(accounts.alice.addr);
        vm.resumeGasMetering();
        activationId = controller.activate(name, config);
        vm.pauseGasMetering();
    }

    function _mint(MintScenario memory scenario) internal returns (uint256 tokenId) {
        vm.prank(accounts.buyer.addr);
        tokenId = controller.mint(scenario.activationId, scenario.label, 365 days, scenario.runtimeData);
    }

    function _meteredMint(MintScenario memory scenario) internal returns (uint256 tokenId) {
        vm.prank(accounts.buyer.addr);
        vm.resumeGasMetering();
        tokenId = controller.mint(scenario.activationId, scenario.label, 365 days, scenario.runtimeData);
        vm.pauseGasMetering();
    }

    function _meteredRenew(MintScenario memory scenario, uint64 duration) internal returns (uint64 newExpiry) {
        vm.prank(accounts.buyer.addr);
        vm.resumeGasMetering();
        newExpiry = controller.renew(scenario.activationId, scenario.label, duration, scenario.runtimeData);
        vm.pauseGasMetering();
    }

    function _mintAndAssert(MintScenario memory scenario) internal returns (uint256 tokenId) {
        tokenId = _mint(scenario);
        _assertMinted(tokenId);
    }

    function _assertMinted(uint256 tokenId) internal view {
        IPermissionedRegistry.State memory state = registry.getState(tokenId);
        assertEq(uint256(state.status), uint256(IPermissionedRegistry.Status.REGISTERED));
        assertEq(registry.ownerOf(tokenId), accounts.buyer.addr);
    }
}
