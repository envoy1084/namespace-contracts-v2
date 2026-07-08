// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LibClone} from "solady/utils/LibClone.sol";

import {PermissionedResolverLib} from "@ensv2/resolver/libraries/PermissionedResolverLib.sol";

import {NamespaceController} from "src/NamespaceController.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {BatchSetAddrToBuyerHook} from "src/modules/hooks/BatchSetAddrToBuyerHook.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {ERC20SplitPaymentModule} from "src/modules/payment/ERC20SplitPaymentModule.sol";
import {FixedPriceRule} from "src/modules/rules/FixedPriceRule.sol";
import {LabelClassRule} from "src/modules/rules/LabelClassRule.sol";
import {LabelLengthRule} from "src/modules/rules/LabelLengthRule.sol";
import {LengthPremiumRule} from "src/modules/rules/LengthPremiumRule.sol";
import {PauseRule} from "src/modules/rules/PauseRule.sol";
import {ReservationRule} from "src/modules/rules/ReservationRule.sol";
import {SaleWindowRule} from "src/modules/rules/SaleWindowRule.sol";
import {TokenBalanceRule} from "src/modules/rules/TokenBalanceRule.sol";
import {USDOracleRule} from "src/modules/rules/USDOracleRule.sol";
import {WhitelistRule} from "src/modules/rules/WhitelistRule.sol";
import {MockAggregatorV3} from "test/mocks/MockAggregatorV3.sol";
import {NamespaceBenchmarkBase} from "test/benchmarks/common/NamespaceBenchmarkBase.sol";
import {NamespaceControllerActivationProbe} from "test/profile/NamespaceControllerActivationProbe.sol";

contract NamespaceActivationSliceProfile is NamespaceBenchmarkBase {
    NamespaceControllerActivationProbe private activationProbe;

    function setUp() public override {
        super.setUp();
        activationProbe = _deployActivationProbe(accounts.owner.addr);

        vm.prank(accounts.owner.addr);
        activationProbe.setUniversalResolver(universalResolver);

        registry.grantRootRoles(ROLE_REGISTRAR | ROLE_RENEW, address(activationProbe));
        _redeployModulesForActivationProbe();
        _approveActivationProbeModules();
    }

    function testProfile_activationNoRules_slices() public {
        NamespaceTypes.ActivationConfig memory config = _freeActivationConfig();

        vm.prank(accounts.alice.addr);
        (, NamespaceControllerActivationProbe.ActivationGasProfile memory profile) =
            activationProbe.activateProfile(_aliceName(), config);

        _logActivationProfile("activation.free", profile);
    }

    function testProfile_activationAllRulesSplitFiveResolverWrites_slices() public {
        ComboSpec memory highSpec = _comboSpec(15, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 5);
        NamespaceTypes.ActivationConfig memory config = _comboConfig("12345", highSpec);

        vm.prank(accounts.alice.addr);
        (, NamespaceControllerActivationProbe.ActivationGasProfile memory profile) =
            activationProbe.activateProfile(_aliceName(), config);

        _logActivationProfile("activation.high", profile);
    }

    function testProfile_activationNoRules_regularControllerGas() public {
        _activateExistingNamespace(_freeActivationConfig());
    }

    function testProfile_activationNoRules_probeTotalGas() public {
        NamespaceTypes.ActivationConfig memory config = _freeActivationConfig();

        vm.prank(accounts.alice.addr);
        activationProbe.activateProfile(_aliceName(), config);
    }

    function _deployActivationProbe(address owner_) private returns (NamespaceControllerActivationProbe deployed) {
        address implementation = address(new NamespaceControllerActivationProbe());
        deployed = NamespaceControllerActivationProbe(payable(LibClone.deployERC1967(implementation)));
        deployed.initialize(owner_);
    }

    function _redeployModulesForActivationProbe() private {
        NamespaceController originalController = controller;
        controller = activationProbe;

        erc20Payment = ERC20PaymentModule(_deployModule(address(new ERC20PaymentModule())));
        saleWindowRule = SaleWindowRule(_deployModule(address(new SaleWindowRule())));
        labelLengthRule = LabelLengthRule(_deployModule(address(new LabelLengthRule())));
        fixedPriceRule = FixedPriceRule(_deployModule(address(new FixedPriceRule())));
        pauseRule = PauseRule(_deployModule(address(new PauseRule())));
        tokenBalanceRule = TokenBalanceRule(_deployModule(address(new TokenBalanceRule())));
        reservationRule = ReservationRule(_deployModule(address(new ReservationRule())));
        whitelistRule = WhitelistRule(_deployModule(address(new WhitelistRule())));
        lengthPremiumRule = LengthPremiumRule(_deployModule(address(new LengthPremiumRule())));
        labelClassRule = LabelClassRule(_deployModule(address(new LabelClassRule())));
        usdOracleRule = USDOracleRule(_deployModule(address(new USDOracleRule())));
        splitPayment = ERC20SplitPaymentModule(_deployModule(address(new ERC20SplitPaymentModule())));
        batchResolverHook = BatchSetAddrToBuyerHook(_deployModule(address(new BatchSetAddrToBuyerHook())));
        resolver = _deployResolver(address(batchResolverHook), PermissionedResolverLib.ROLE_SET_ADDR);
        oracle = new MockAggregatorV3(8, 2_000e8);

        controller = originalController;
    }

    function _approveActivationProbeModules() private {
        bytes32 ruleKind = activationProbe.MODULE_KIND_RULE();
        bytes32 paymentKind = activationProbe.MODULE_KIND_PAYMENT();
        bytes32 postHookKind = activationProbe.MODULE_KIND_POST_HOOK();

        vm.startPrank(accounts.owner.addr);
        activationProbe.setModuleApproval(ruleKind, address(saleWindowRule), true);
        activationProbe.setModuleApproval(ruleKind, address(labelLengthRule), true);
        activationProbe.setModuleApproval(ruleKind, address(fixedPriceRule), true);
        activationProbe.setModuleApproval(ruleKind, address(pauseRule), true);
        activationProbe.setModuleApproval(ruleKind, address(tokenBalanceRule), true);
        activationProbe.setModuleApproval(ruleKind, address(reservationRule), true);
        activationProbe.setModuleApproval(ruleKind, address(whitelistRule), true);
        activationProbe.setModuleApproval(ruleKind, address(lengthPremiumRule), true);
        activationProbe.setModuleApproval(ruleKind, address(labelClassRule), true);
        activationProbe.setModuleApproval(ruleKind, address(usdOracleRule), true);
        activationProbe.setModuleApproval(paymentKind, address(erc20Payment), true);
        activationProbe.setModuleApproval(paymentKind, address(splitPayment), true);
        activationProbe.setModuleApproval(postHookKind, address(batchResolverHook), true);
        vm.stopPrank();
    }

    function _logActivationProfile(
        string memory prefix,
        NamespaceControllerActivationProbe.ActivationGasProfile memory profile
    ) private {
        emit log_named_uint(string.concat(prefix, ".loadResolverAndValidateName"), profile.loadResolverAndValidateName);
        emit log_named_uint(string.concat(prefix, ".findExactRegistry"), profile.findExactRegistry);
        emit log_named_uint(string.concat(prefix, ".findParentRegistry"), profile.findParentRegistry);
        emit log_named_uint(string.concat(prefix, ".labelHashAndParentState"), profile.labelHashAndParentState);
        emit log_named_uint(string.concat(prefix, ".parentSubregistryCheck"), profile.parentSubregistryCheck);
        emit log_named_uint(string.concat(prefix, ".namehashAndActivationKey"), profile.namehashAndActivationKey);
        emit log_named_uint(string.concat(prefix, ".durationAndPaymentChecks"), profile.durationAndPaymentChecks);
        emit log_named_uint(string.concat(prefix, ".ownerAdminCheck"), profile.ownerAdminCheck);
        emit log_named_uint(
            string.concat(prefix, ".controllerRegistryRolesCheck"), profile.controllerRegistryRolesCheck
        );
        emit log_named_uint(string.concat(prefix, ".activationIdCheck"), profile.activationIdCheck);
        emit log_named_uint(string.concat(prefix, ".storeModuleLists"), profile.storeModuleLists);
        emit log_named_uint(string.concat(prefix, ".storeActivation"), profile.storeActivation);
        emit log_named_uint(string.concat(prefix, ".store.ownerAndRegistries"), profile.storeOwnerAndRegistries);
        emit log_named_uint(string.concat(prefix, ".store.namespaceIdentity"), profile.storeNamespaceIdentity);
        emit log_named_uint(string.concat(prefix, ".store.namespaceLabel"), profile.storeNamespaceLabel);
        emit log_named_uint(string.concat(prefix, ".store.mintConfig"), profile.storeMintConfig);
        emit log_named_uint(string.concat(prefix, ".store.moduleRefs"), profile.storeModuleRefs);
        emit log_named_uint(string.concat(prefix, ".emitActivationEvents"), profile.emitActivationEvents);
        emit log_named_uint(string.concat(prefix, ".configureModules"), profile.configureModules);
        emit log_named_uint(string.concat(prefix, ".measuredBodyTotal"), profile.measuredBodyTotal);
        emit log_named_uint(
            string.concat(prefix, ".universalResolverDiscovery"), profile.findExactRegistry + profile.findParentRegistry
        );
    }
}
