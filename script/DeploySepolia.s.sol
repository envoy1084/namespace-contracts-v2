// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {LibClone} from "solady/utils/LibClone.sol";

import {NamespaceController} from "src/NamespaceController.sol";
import {IUniversalResolverV2} from "@ensv2/universalResolver/interfaces/IUniversalResolverV2.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";
import {BatchSetAddrToBuyerHook} from "src/modules/hooks/BatchSetAddrToBuyerHook.sol";
import {SetAddrToBuyerHook} from "src/modules/hooks/SetAddrToBuyerHook.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {ERC20SplitPaymentModule} from "src/modules/payment/ERC20SplitPaymentModule.sol";
import {NativePaymentModule} from "src/modules/payment/NativePaymentModule.sol";
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

/// @notice Sepolia-only Forge deployment for Namespace controller and production modules.
/// @dev ENSv2 addresses are copied from lib/contracts-v2/contracts/docs/addresses/sepolia.md.
contract DeploySepolia is Script {
    uint256 internal constant SEPOLIA_CHAIN_ID = 11_155_111;

    address internal constant SEPOLIA_UNIVERSAL_RESOLVER = 0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe;
    address internal constant SEPOLIA_MANAGED_UNIVERSAL_RESOLVER = 0x6d80F2172CFdEc5730fE683860C33d26fC42e6F1;
    address internal constant SEPOLIA_UNIVERSAL_RESOLVER_IMPLEMENTATION = 0x85eDf8B6b7D4211e2b07AA687506B746357B92cf;
    address internal constant SEPOLIA_ROOT_REGISTRY = 0x11b5BfbE9078D826b1eDBDd1cFC12f5828D9F50C;
    address internal constant SEPOLIA_ETH_REGISTRY = 0x67b728a792e789a8978b30cF1b3b641f19354b43;
    address internal constant SEPOLIA_LABEL_STORE = 0xB03524289C16424f71802A1794c29c7Bd1B9f577;

    error NotSepolia(uint256 chainId);

    struct ModuleDeployment {
        string name;
        address implementation;
        address proxy;
    }

    function run() external {
        if (block.chainid != SEPOLIA_CHAIN_ID) revert NotSepolia(block.chainid);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        NamespaceController controller = _deployController(deployer);
        ModuleDeployment[] memory rules = _deployRuleModules(controller, deployer);
        ModuleDeployment[] memory payments = _deployPaymentModules(controller, deployer);
        ModuleDeployment[] memory hooks = _deployHookModules(controller, deployer);

        _approveModules(controller, controller.MODULE_KIND_RULE(), rules);
        _approveModules(controller, controller.MODULE_KIND_PAYMENT(), payments);
        _approveModules(controller, controller.MODULE_KIND_POST_HOOK(), hooks);

        vm.stopBroadcast();

        console2.log("Namespace deployment complete");
        console2.log("Controller owner", deployer);
        console2.log("Module owner", deployer);
        console2.log("ENSv2 UniversalResolver", SEPOLIA_UNIVERSAL_RESOLVER);
        console2.log("Controller RootRegistry mirror", address(controller.rootRegistry()));
        console2.log("Controller proxy", address(controller));
    }

    function _deployController(address owner) internal returns (NamespaceController controller) {
        address implementation = address(new NamespaceController());
        controller = NamespaceController(payable(LibClone.deployERC1967(implementation)));
        controller.initialize(owner);
        controller.setUniversalResolver(IUniversalResolverV2(SEPOLIA_UNIVERSAL_RESOLVER));

        console2.log("NamespaceController implementation", implementation);
        console2.log("NamespaceController proxy", address(controller));
    }

    function _deployRuleModules(NamespaceController controller, address moduleOwner)
        internal
        returns (ModuleDeployment[] memory modules)
    {
        modules = new ModuleDeployment[](10);
        modules[0] = _deployModule("PauseRule", address(new PauseRule()), controller, moduleOwner);
        modules[1] = _deployModule("SaleWindowRule", address(new SaleWindowRule()), controller, moduleOwner);
        modules[2] = _deployModule("LabelLengthRule", address(new LabelLengthRule()), controller, moduleOwner);
        modules[3] = _deployModule("FixedPriceRule", address(new FixedPriceRule()), controller, moduleOwner);
        modules[4] = _deployModule("LengthPremiumRule", address(new LengthPremiumRule()), controller, moduleOwner);
        modules[5] = _deployModule("LabelClassRule", address(new LabelClassRule()), controller, moduleOwner);
        modules[6] = _deployModule("USDOracleRule", address(new USDOracleRule()), controller, moduleOwner);
        modules[7] = _deployModule("TokenBalanceRule", address(new TokenBalanceRule()), controller, moduleOwner);
        modules[8] = _deployModule("ReservationRule", address(new ReservationRule()), controller, moduleOwner);
        modules[9] = _deployModule("WhitelistRule", address(new WhitelistRule()), controller, moduleOwner);
    }

    function _deployPaymentModules(NamespaceController controller, address moduleOwner)
        internal
        returns (ModuleDeployment[] memory modules)
    {
        modules = new ModuleDeployment[](3);
        modules[0] = _deployModule("NativePaymentModule", address(new NativePaymentModule()), controller, moduleOwner);
        modules[1] = _deployModule("ERC20PaymentModule", address(new ERC20PaymentModule()), controller, moduleOwner);
        modules[2] =
            _deployModule("ERC20SplitPaymentModule", address(new ERC20SplitPaymentModule()), controller, moduleOwner);
    }

    function _deployHookModules(NamespaceController controller, address moduleOwner)
        internal
        returns (ModuleDeployment[] memory modules)
    {
        modules = new ModuleDeployment[](2);
        modules[0] = _deployModule("SetAddrToBuyerHook", address(new SetAddrToBuyerHook()), controller, moduleOwner);
        modules[1] =
            _deployModule("BatchSetAddrToBuyerHook", address(new BatchSetAddrToBuyerHook()), controller, moduleOwner);
    }

    function _deployModule(
        string memory name,
        address implementation,
        NamespaceController controller,
        address moduleOwner
    ) internal returns (ModuleDeployment memory deployment) {
        address proxy = LibClone.deployERC1967(implementation);
        NamespaceModule(proxy).initialize(address(controller), moduleOwner);
        deployment = ModuleDeployment({name: name, implementation: implementation, proxy: proxy});

        console2.log(string.concat(name, " implementation"), implementation);
        console2.log(string.concat(name, " proxy"), proxy);
    }

    function _approveModules(NamespaceController controller, bytes32 kind, ModuleDeployment[] memory modules) internal {
        uint256 length = modules.length;
        for (uint256 i; i < length;) {
            controller.setModuleApproval(kind, modules[i].proxy, true);
            console2.log("Approved module", modules[i].name);
            console2.log("Approved module proxy", modules[i].proxy);
            unchecked {
                ++i;
            }
        }
    }
}
