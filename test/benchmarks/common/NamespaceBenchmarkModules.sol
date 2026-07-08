// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PermissionedResolverLib} from "@ensv2/resolver/libraries/PermissionedResolverLib.sol";
import {PermissionedResolver} from "@ensv2/resolver/PermissionedResolver.sol";
import {VerifiableFactory} from "lib/contracts-v2/contracts/lib/verifiable-factory/src/VerifiableFactory.sol";

import {BatchSetAddrToBuyerHook} from "src/modules/hooks/BatchSetAddrToBuyerHook.sol";
import {SetAddrToBuyerHook} from "src/modules/hooks/SetAddrToBuyerHook.sol";
import {ERC20SplitPaymentModule} from "src/modules/payment/ERC20SplitPaymentModule.sol";
import {LabelClassRule} from "src/modules/rules/LabelClassRule.sol";
import {LengthPremiumRule} from "src/modules/rules/LengthPremiumRule.sol";
import {PauseRule} from "src/modules/rules/PauseRule.sol";
import {ReservationRule} from "src/modules/rules/ReservationRule.sol";
import {TokenBalanceRule} from "src/modules/rules/TokenBalanceRule.sol";
import {USDOracleRule} from "src/modules/rules/USDOracleRule.sol";
import {WhitelistRule} from "src/modules/rules/WhitelistRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";
import {MockAggregatorV3} from "test/mocks/MockAggregatorV3.sol";

/// @notice Deploys and approves the optional modules used by gas benchmarks.
abstract contract NamespaceBenchmarkModules is NamespaceSetUp {
    PauseRule internal pauseRule;
    TokenBalanceRule internal tokenBalanceRule;
    ReservationRule internal reservationRule;
    WhitelistRule internal whitelistRule;
    LengthPremiumRule internal lengthPremiumRule;
    LabelClassRule internal labelClassRule;
    USDOracleRule internal usdOracleRule;
    ERC20SplitPaymentModule internal splitPayment;
    SetAddrToBuyerHook internal setAddrHook;
    BatchSetAddrToBuyerHook internal batchResolverHook;
    PermissionedResolver internal setAddrResolver;
    PermissionedResolver internal resolver;
    MockAggregatorV3 internal oracle;

    function setUp() public virtual override {
        super.setUp();

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

        _approveBenchmarkModules();

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), type(uint256).max);
        token.approve(address(splitPayment), type(uint256).max);
        vm.stopPrank();
    }

    function _deployResolver(address admin, uint256 roles) internal returns (PermissionedResolver) {
        VerifiableFactory factory = new VerifiableFactory();
        PermissionedResolver resolverImpl = new PermissionedResolver(admin);
        bytes[] memory setters = new bytes[](0);
        bytes memory initData = abi.encodeCall(PermissionedResolver.initialize, (admin, roles, setters));
        return PermissionedResolver(factory.deployProxy(address(resolverImpl), uint256(keccak256(initData)), initData));
    }

    function _approveBenchmarkModules() private {
        bytes32 ruleKind = controller.MODULE_KIND_RULE();
        bytes32 paymentKind = controller.MODULE_KIND_PAYMENT();
        bytes32 postHookKind = controller.MODULE_KIND_POST_HOOK();

        vm.startPrank(accounts.owner.addr);
        controller.setModuleApproval(ruleKind, address(pauseRule), true);
        controller.setModuleApproval(ruleKind, address(tokenBalanceRule), true);
        controller.setModuleApproval(ruleKind, address(reservationRule), true);
        controller.setModuleApproval(ruleKind, address(whitelistRule), true);
        controller.setModuleApproval(ruleKind, address(lengthPremiumRule), true);
        controller.setModuleApproval(ruleKind, address(labelClassRule), true);
        controller.setModuleApproval(ruleKind, address(usdOracleRule), true);
        controller.setModuleApproval(paymentKind, address(splitPayment), true);
        controller.setModuleApproval(postHookKind, address(setAddrHook), true);
        controller.setModuleApproval(postHookKind, address(batchResolverHook), true);
        vm.stopPrank();
    }
}
