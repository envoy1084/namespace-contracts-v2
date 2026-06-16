// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {ERC20BalanceGatePolicy} from "src/modules/policies/ERC20BalanceGatePolicy.sol";
import {LabelLengthPolicy} from "src/modules/policies/LabelLengthPolicy.sol";
import {MerkleWhitelistPolicy} from "src/modules/policies/MerkleWhitelistPolicy.sol";
import {ReservationPolicy} from "src/modules/policies/ReservationPolicy.sol";
import {SaleWindowPolicy} from "src/modules/policies/SaleWindowPolicy.sol";
import {FixedPricePricing} from "src/modules/pricing/FixedPricePricing.sol";
import {LengthBasedPricing} from "src/modules/pricing/LengthBasedPricing.sol";
import {ERC20SplitProcessor} from "src/modules/processors/ERC20SplitProcessor.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract NamespaceActivationFlowTest is NamespaceSetUp {
    ERC20BalanceGatePolicy internal erc20GatePolicy;
    ReservationPolicy internal reservationPolicy;
    MerkleWhitelistPolicy internal whitelistPolicy;
    LengthBasedPricing internal lengthPricing;
    ERC20SplitProcessor internal splitProcessor;

    function setUp() public override {
        super.setUp();
        erc20GatePolicy = new ERC20BalanceGatePolicy(address(controller));
        reservationPolicy = new ReservationPolicy(address(controller));
        whitelistPolicy = new MerkleWhitelistPolicy(address(controller));
        lengthPricing = new LengthBasedPricing(address(controller));
        splitProcessor = new ERC20SplitProcessor(address(controller));

        vm.startPrank(accounts.owner.addr);
        controller.setModuleApproval(controller.MODULE_KIND_POLICY(), address(erc20GatePolicy), true);
        controller.setModuleApproval(controller.MODULE_KIND_POLICY(), address(reservationPolicy), true);
        controller.setModuleApproval(controller.MODULE_KIND_POLICY(), address(whitelistPolicy), true);
        controller.setModuleApproval(controller.MODULE_KIND_PRICING(), address(lengthPricing), true);
        controller.setModuleApproval(controller.MODULE_KIND_PROCESSOR(), address(splitProcessor), true);
        vm.stopPrank();
    }

    function test_mint_executesFullPolicyPricingPaymentProcessorRegistryFlow() public {
        string memory label = "vip";
        bytes32 labelHash = keccak256(bytes(label));
        uint64 duration = 10;
        bytes32 buyerLeaf = _accountLabelLeaf(accounts.buyer.addr, labelHash);
        bytes32 aliceLeaf = _accountLabelLeaf(accounts.alice.addr, labelHash);
        bytes32 whitelistRoot = _hashPair(buyerLeaf, aliceLeaf);

        NamespaceTypes.ActivationConfig memory config = _integrationActivationConfig(labelHash, whitelistRoot);

        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(config);

        NamespaceTypes.RuntimeData memory runtimeData;
        runtimeData.policyData = new bytes[](5);
        runtimeData.policyData[3] = abi.encode(
            ReservationPolicy.ProofData({
                account: accounts.buyer.addr, expiry: uint64(block.timestamp + 1 days), proof: new bytes32[](0)
            })
        );
        bytes32[] memory whitelistProof = new bytes32[](1);
        whitelistProof[0] = aliceLeaf;
        runtimeData.policyData[4] = abi.encode(whitelistProof);
        runtimeData.pricingData = new bytes[](2);
        runtimeData.postHookData = new bytes[](1);
        runtimeData.postHookData[0] = hex"cafe";

        uint256 quotedPrice = 100 ether + 20 ether;

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), quotedPrice);
        uint256 tokenId = controller.mint(activationId, label, duration, runtimeData);
        vm.stopPrank();

        IPermissionedRegistry.State memory state = registry.getState(tokenId);
        assertEq(uint256(state.status), uint256(IPermissionedRegistry.Status.REGISTERED));
        assertEq(state.latestOwner, accounts.buyer.addr);
        assertEq(registry.ownerOf(tokenId), accounts.buyer.addr);
        assertEq(registry.getResolver(label), address(0xBEEF));
        assertEq(registry.roles(tokenId, accounts.buyer.addr), BUYER_ROLES);

        assertEq(token.balanceOf(accounts.alice.addr), 90 ether);
        assertEq(token.balanceOf(accounts.treasury.addr), 30 ether);
        assertEq(token.balanceOf(address(splitProcessor)), 0);

        assertEq(postHook.lastActivationId(), activationId);
        assertEq(postHook.lastBuyer(), accounts.buyer.addr);
        assertEq(postHook.lastLabelHash(), labelHash);
        assertEq(postHook.lastTokenId(), tokenId);
        assertEq(postHook.lastRuntimeData(), hex"cafe");
    }

    function _integrationActivationConfig(bytes32 labelHash, bytes32 whitelistRoot)
        private
        view
        returns (NamespaceTypes.ActivationConfig memory config)
    {
        NamespaceTypes.ModuleConfig[] memory policies = new NamespaceTypes.ModuleConfig[](5);
        policies[0] = NamespaceTypes.ModuleConfig({
            module: address(saleWindowPolicy),
            configData: abi.encode(SaleWindowPolicy.Params({startTime: uint64(block.timestamp), endTime: 0}))
        });
        policies[1] = NamespaceTypes.ModuleConfig({
            module: address(labelLengthPolicy),
            configData: abi.encode(LabelLengthPolicy.Params({minLength: 3, maxLength: 12}))
        });
        policies[2] = NamespaceTypes.ModuleConfig({
            module: address(erc20GatePolicy),
            configData: abi.encode(ERC20BalanceGatePolicy.Params({token: token, minBalance: 100 ether}))
        });

        bytes32 reservationRoot =
            reservationPolicy.leaf(labelHash, accounts.buyer.addr, uint64(block.timestamp + 1 days));
        policies[3] = NamespaceTypes.ModuleConfig({
            module: address(reservationPolicy),
            configData: abi.encode(ReservationPolicy.Params({reservationRoot: reservationRoot}))
        });
        policies[4] = NamespaceTypes.ModuleConfig({
            module: address(whitelistPolicy),
            configData: abi.encode(
                MerkleWhitelistPolicy.Params({
                    mintRoot: whitelistRoot,
                    renewRoot: bytes32(0),
                    leafMode: MerkleWhitelistPolicy.LeafMode.ACCOUNT_LABEL
                })
            )
        });

        NamespaceTypes.ModuleConfig[] memory pricingModules = new NamespaceTypes.ModuleConfig[](2);
        pricingModules[0] = NamespaceTypes.ModuleConfig({
            module: address(fixedPricePricing),
            configData: abi.encode(
                FixedPricePricing.Params({
                    token: address(token),
                    defaultMintAmount: 100 ether,
                    defaultRenewAmount: 50 ether,
                    lengthPrices: new FixedPricePricing.LengthPrice[](0)
                })
            )
        });

        uint128[] memory mintRates = new uint128[](3);
        mintRates[0] = 0;
        mintRates[1] = 0;
        mintRates[2] = 2 ether;
        uint128[] memory renewRates = new uint128[](1);
        renewRates[0] = 1 ether;
        pricingModules[1] = NamespaceTypes.ModuleConfig({
            module: address(lengthPricing),
            configData: abi.encode(
                LengthBasedPricing.Params({
                    token: address(token),
                    mintPricePerSecondByLength: mintRates,
                    renewPricePerSecondByLength: renewRates
                })
            )
        });

        ERC20SplitProcessor.Split[] memory splits = new ERC20SplitProcessor.Split[](2);
        splits[0] = ERC20SplitProcessor.Split({recipient: accounts.alice.addr, bps: 7500});
        splits[1] = ERC20SplitProcessor.Split({recipient: accounts.treasury.addr, bps: 2500});

        NamespaceTypes.ModuleConfig[] memory postHooks = new NamespaceTypes.ModuleConfig[](1);
        postHooks[0] = NamespaceTypes.ModuleConfig({module: address(postHook), configData: ""});

        config = NamespaceTypes.ActivationConfig({
            registry: IPermissionedRegistry(address(registry)),
            parentNode: keccak256("alice.eth"),
            resolver: address(0xBEEF),
            buyerRoleBitmap: BUYER_ROLES,
            policies: policies,
            pricingModules: pricingModules,
            paymentModule: NamespaceTypes.ModuleConfig({
                module: address(erc20Payment),
                configData: abi.encode(ERC20PaymentModule.Params({token: token, recipient: address(splitProcessor)}))
            }),
            processor: NamespaceTypes.ModuleConfig({module: address(splitProcessor), configData: abi.encode(splits)}),
            postHooks: postHooks
        });
    }

    function _accountLabelLeaf(address account, bytes32 labelHash) private pure returns (bytes32 result) {
        bytes32 inner;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, account)
            mstore(add(ptr, 0x20), labelHash)
            inner := keccak256(ptr, 0x40)
            mstore(ptr, inner)
            result := keccak256(ptr, 0x20)
        }
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            let first := b
            let second := a
            if lt(a, b) {
                first := a
                second := b
            }
            mstore(ptr, first)
            mstore(add(ptr, 0x20), second)
            result := keccak256(ptr, 0x40)
        }
    }
}
