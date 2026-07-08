// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LibClone} from "solady/utils/LibClone.sol";

import {PermissionedResolverLib} from "@ensv2/resolver/libraries/PermissionedResolverLib.sol";

import {BatchSetAddrToBuyerHook} from "src/modules/hooks/BatchSetAddrToBuyerHook.sol";
import {SetAddrToBuyerHook} from "src/modules/hooks/SetAddrToBuyerHook.sol";
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
import {RecordingPostHook} from "test/mocks/RecordingPostHook.sol";
import {NamespaceBenchmarkBase} from "test/benchmarks/common/NamespaceBenchmarkBase.sol";
import {NamespaceControllerRuntimeProbe} from "test/profile/NamespaceControllerRuntimeProbe.sol";

contract NamespaceRuntimeSliceProfile is NamespaceBenchmarkBase {
    NamespaceControllerRuntimeProbe private runtimeProbe;

    MintScenario private mintFreeNoRules;
    MintScenario private mintAllRulesSplitFiveResolverWrites;
    MintScenario private renewFreeNoRules;
    MintScenario private renewAllRulesSplitFiveResolverWrites;

    function setUp() public override {
        super.setUp();

        runtimeProbe = _deployRuntimeProbe(accounts.owner.addr);
        controller = runtimeProbe;

        vm.prank(accounts.owner.addr);
        runtimeProbe.setUniversalResolver(universalResolver);
        registry.grantRootRoles(ROLE_REGISTRAR | ROLE_RENEW, address(runtimeProbe));

        _redeployModulesForRuntimeProbe();
        _approveRuntimeProbeModules();

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), type(uint256).max);
        token.approve(address(splitPayment), type(uint256).max);
        vm.stopPrank();

        ComboSpec memory freeSpec = _comboSpec(0, PaymentMode.NONE, HookMode.NONE, 0);
        ComboSpec memory highSpec = _comboSpec(15, PaymentMode.SPLIT, HookMode.BATCH_RESOLVER, 5);

        mintFreeNoRules =
            _prepareMintScenario("free", _comboConfig("free", freeSpec), _comboRuntimeData("free", freeSpec));
        mintAllRulesSplitFiveResolverWrites =
            _prepareMintScenario("12345", _comboConfig("12345", highSpec), _comboRuntimeData("12345", highSpec));
        renewFreeNoRules = _prepareRenewScenario(
            "renewfree", _comboConfig("renewfree", freeSpec), _comboRuntimeData("renewfree", freeSpec)
        );
        renewAllRulesSplitFiveResolverWrites =
            _prepareRenewScenario("12345", _comboConfig("12345", highSpec), _comboRuntimeData("12345", highSpec));
    }

    function testProfile_mint_00_freeNoRules_slices() public {
        vm.prank(accounts.buyer.addr);
        (, NamespaceControllerRuntimeProbe.RuntimeGasProfile memory profile) = runtimeProbe.mintProfile(
            mintFreeNoRules.activationId, mintFreeNoRules.label, 365 days, mintFreeNoRules.runtimeData
        );
        _logMintProfile("mint.free", profile);
    }

    function testProfile_mint_01_allRulesSplitFiveResolverWrites_slices() public {
        vm.prank(accounts.buyer.addr);
        (, NamespaceControllerRuntimeProbe.RuntimeGasProfile memory profile) = runtimeProbe.mintProfile(
            mintAllRulesSplitFiveResolverWrites.activationId,
            mintAllRulesSplitFiveResolverWrites.label,
            365 days,
            mintAllRulesSplitFiveResolverWrites.runtimeData
        );
        _logMintProfile("mint.high", profile);
    }

    function testProfile_renew_00_freeNoRules_slices() public {
        vm.prank(accounts.buyer.addr);
        (, NamespaceControllerRuntimeProbe.RuntimeGasProfile memory profile) = runtimeProbe.renewProfile(
            renewFreeNoRules.activationId, renewFreeNoRules.label, 30 days, renewFreeNoRules.runtimeData
        );
        _logRenewProfile("renew.free", profile);
    }

    function testProfile_renew_01_allRulesSplitFiveResolverWrites_slices() public {
        vm.prank(accounts.buyer.addr);
        (, NamespaceControllerRuntimeProbe.RuntimeGasProfile memory profile) = runtimeProbe.renewProfile(
            renewAllRulesSplitFiveResolverWrites.activationId,
            renewAllRulesSplitFiveResolverWrites.label,
            30 days,
            renewAllRulesSplitFiveResolverWrites.runtimeData
        );
        _logRenewProfile("renew.high", profile);
    }

    function _redeployModulesForRuntimeProbe() private {
        erc20Payment = ERC20PaymentModule(_deployModule(address(new ERC20PaymentModule())));
        postHook = RecordingPostHook(_deployModule(address(new RecordingPostHook())));
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
        setAddrHook = SetAddrToBuyerHook(_deployModule(address(new SetAddrToBuyerHook())));
        batchResolverHook = BatchSetAddrToBuyerHook(_deployModule(address(new BatchSetAddrToBuyerHook())));
        setAddrResolver = _deployResolver(address(setAddrHook), PermissionedResolverLib.ROLE_SET_ADDR);
        resolver = _deployResolver(address(batchResolverHook), PermissionedResolverLib.ROLE_SET_ADDR);
        oracle = new MockAggregatorV3(8, 2_000e8);
    }

    function _approveRuntimeProbeModules() private {
        bytes32 ruleKind = runtimeProbe.MODULE_KIND_RULE();
        bytes32 paymentKind = runtimeProbe.MODULE_KIND_PAYMENT();
        bytes32 postHookKind = runtimeProbe.MODULE_KIND_POST_HOOK();

        vm.startPrank(accounts.owner.addr);
        runtimeProbe.setModuleApproval(ruleKind, address(saleWindowRule), true);
        runtimeProbe.setModuleApproval(ruleKind, address(labelLengthRule), true);
        runtimeProbe.setModuleApproval(ruleKind, address(fixedPriceRule), true);
        runtimeProbe.setModuleApproval(ruleKind, address(pauseRule), true);
        runtimeProbe.setModuleApproval(ruleKind, address(tokenBalanceRule), true);
        runtimeProbe.setModuleApproval(ruleKind, address(reservationRule), true);
        runtimeProbe.setModuleApproval(ruleKind, address(whitelistRule), true);
        runtimeProbe.setModuleApproval(ruleKind, address(lengthPremiumRule), true);
        runtimeProbe.setModuleApproval(ruleKind, address(labelClassRule), true);
        runtimeProbe.setModuleApproval(ruleKind, address(usdOracleRule), true);
        runtimeProbe.setModuleApproval(paymentKind, address(erc20Payment), true);
        runtimeProbe.setModuleApproval(paymentKind, address(splitPayment), true);
        runtimeProbe.setModuleApproval(postHookKind, address(postHook), true);
        runtimeProbe.setModuleApproval(postHookKind, address(setAddrHook), true);
        runtimeProbe.setModuleApproval(postHookKind, address(batchResolverHook), true);
        vm.stopPrank();
    }

    function _deployRuntimeProbe(address owner_) private returns (NamespaceControllerRuntimeProbe deployed) {
        address implementation = address(new NamespaceControllerRuntimeProbe());
        deployed = NamespaceControllerRuntimeProbe(payable(LibClone.deployERC1967(implementation)));
        deployed.initialize(owner_);
    }

    function _logMintProfile(string memory prefix, NamespaceControllerRuntimeProbe.RuntimeGasProfile memory profile)
        private
    {
        emit log_named_uint(string.concat(prefix, ".activationLoadAndActive"), profile.activationLoadAndActive);
        emit log_named_uint(string.concat(prefix, ".namespaceCurrent"), profile.namespaceCurrent);
        emit log_named_uint(string.concat(prefix, ".ownerAdminCheck"), profile.ownerAdminCheck);
        emit log_named_uint(string.concat(prefix, ".durationAndRuntimeChecks"), profile.durationAndRuntimeChecks);
        emit log_named_uint(string.concat(prefix, ".labelHashAndContext"), profile.labelHashAndContext);
        emit log_named_uint(string.concat(prefix, ".labelActivationStore"), profile.labelActivationStore);
        emit log_named_uint(string.concat(prefix, ".evaluateRules"), profile.evaluateRules);
        emit log_named_uint(string.concat(prefix, ".registryWrite"), profile.registryWrite);
        emit log_named_uint(string.concat(prefix, ".collectPayment"), profile.collectPayment);
        emit log_named_uint(string.concat(prefix, ".postHooks"), profile.postHooks);
        emit log_named_uint(string.concat(prefix, ".emitEvent"), profile.emitEvent);
        emit log_named_uint(string.concat(prefix, ".measuredBodyTotal"), profile.measuredBodyTotal);
    }

    function _logRenewProfile(string memory prefix, NamespaceControllerRuntimeProbe.RuntimeGasProfile memory profile)
        private
    {
        emit log_named_uint(string.concat(prefix, ".activationLoadAndActive"), profile.activationLoadAndActive);
        emit log_named_uint(string.concat(prefix, ".namespaceCurrent"), profile.namespaceCurrent);
        emit log_named_uint(string.concat(prefix, ".ownerAdminCheck"), profile.ownerAdminCheck);
        emit log_named_uint(string.concat(prefix, ".durationAndRuntimeChecks"), profile.durationAndRuntimeChecks);
        emit log_named_uint(
            string.concat(prefix, ".labelStateAndActivationCheck"), profile.labelStateAndActivationCheck
        );
        emit log_named_uint(string.concat(prefix, ".expiryAndContext"), profile.expiryAndContext);
        emit log_named_uint(string.concat(prefix, ".evaluateRules"), profile.evaluateRules);
        emit log_named_uint(string.concat(prefix, ".registryWrite"), profile.registryWrite);
        emit log_named_uint(string.concat(prefix, ".collectPayment"), profile.collectPayment);
        emit log_named_uint(string.concat(prefix, ".postHooks"), profile.postHooks);
        emit log_named_uint(string.concat(prefix, ".emitEvent"), profile.emitEvent);
        emit log_named_uint(string.concat(prefix, ".measuredBodyTotal"), profile.measuredBodyTotal);
    }
}
