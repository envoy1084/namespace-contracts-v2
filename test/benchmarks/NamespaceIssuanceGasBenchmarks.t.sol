// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

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

/// @notice Gas benchmarks for Namespace subname issuance scenarios.
/// @dev Run only these benchmarks with:
///      forge snapshot --match-path 'test/benchmarks/*.t.sol' --snap test/benchmarks/.gas-snapshot
contract NamespaceIssuanceGasBenchmarks is NamespaceSetUp {
    ERC20BalanceGatePolicy internal erc20GatePolicy;
    ReservationPolicy internal reservationPolicy;
    MerkleWhitelistPolicy internal whitelistPolicy;
    LengthBasedPricing internal lengthPricing;
    ERC20SplitProcessor internal splitProcessor;

    bytes32 internal freeActivationId;
    bytes32 internal onePolicyActivationId;
    bytes32 internal threePolicyActivationId;
    bytes32 internal fivePolicyActivationId;
    bytes32 internal fixedErc20ActivationId;
    bytes32 internal lengthPricingActivationId;
    bytes32 internal splitThreePolicyActivationId;
    bytes32 internal fullStackActivationId;

    NamespaceTypes.RuntimeData internal freeRuntimeData;
    NamespaceTypes.RuntimeData internal onePolicyRuntimeData;
    NamespaceTypes.RuntimeData internal threePolicyRuntimeData;
    NamespaceTypes.RuntimeData internal fivePolicyRuntimeData;
    NamespaceTypes.RuntimeData internal fixedErc20RuntimeData;
    NamespaceTypes.RuntimeData internal lengthPricingRuntimeData;
    NamespaceTypes.RuntimeData internal splitThreePolicyRuntimeData;
    NamespaceTypes.RuntimeData internal fullStackRuntimeData;

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

        freeActivationId = _activate("free", 0, 0, false, false, false);
        onePolicyActivationId = _activate("onepolicy", 1, 0, false, false, false);
        threePolicyActivationId = _activate("threepolicy", 3, 0, false, false, false);
        fivePolicyActivationId = _activate("fivepolicy", 5, 0, false, false, true);
        fixedErc20ActivationId = _activate("fixedpay", 0, 1, false, false, false);
        lengthPricingActivationId = _activate("lengthpay", 2, 2, false, false, false);
        splitThreePolicyActivationId = _activate("splitpay", 3, 1, true, false, false);
        fullStackActivationId = _activate("fullstack", 5, 2, true, true, true);

        freeRuntimeData = _runtimeData(0, 0, false, false);
        onePolicyRuntimeData = _runtimeData(1, 0, false, false);
        threePolicyRuntimeData = _runtimeData(3, 0, false, false);
        fivePolicyRuntimeData = _runtimeData(5, 0, true, false);
        fixedErc20RuntimeData = _runtimeData(0, 1, false, false);
        lengthPricingRuntimeData = _runtimeData(2, 2, false, false);
        splitThreePolicyRuntimeData = _runtimeData(3, 1, false, false);
        fullStackRuntimeData = _runtimeData(5, 2, true, true);

        vm.prank(accounts.buyer.addr);
        token.approve(address(erc20Payment), type(uint256).max);
    }

    function testBenchmark_freeMint_noPolicyNoPricing() public {
        _mint(freeActivationId, "free", freeRuntimeData);
    }

    function testBenchmark_freeMint_onePolicy() public {
        _mint(onePolicyActivationId, "onepolicy", onePolicyRuntimeData);
    }

    function testBenchmark_freeMint_threePolicies() public {
        _mint(threePolicyActivationId, "threepolicy", threePolicyRuntimeData);
    }

    function testBenchmark_freeMint_fivePolicies() public {
        _mint(fivePolicyActivationId, "fivepolicy", fivePolicyRuntimeData);
    }

    function testBenchmark_erc20FixedPrice_noPolicy() public {
        _mint(fixedErc20ActivationId, "fixedpay", fixedErc20RuntimeData);
    }

    function testBenchmark_lengthPricing_twoPolicies() public {
        _mint(lengthPricingActivationId, "lengthpay", lengthPricingRuntimeData);
    }

    function testBenchmark_erc20Split_threePolicies() public {
        _mint(splitThreePolicyActivationId, "splitpay", splitThreePolicyRuntimeData);
    }

    function testBenchmark_fullStack_fivePoliciesTwoPricingSplitHook() public {
        _mint(fullStackActivationId, "fullstack", fullStackRuntimeData);
    }

    function _mint(bytes32 activationId, string memory label, NamespaceTypes.RuntimeData memory runtimeData) private {
        vm.prank(accounts.buyer.addr);
        uint256 tokenId = controller.mint(activationId, label, 365 days, runtimeData);
        IPermissionedRegistry.State memory state = registry.getState(tokenId);
        assertEq(uint256(state.status), uint256(IPermissionedRegistry.Status.REGISTERED));
        assertEq(registry.ownerOf(tokenId), accounts.buyer.addr);
    }

    function _activate(
        string memory label,
        uint256 policyCount,
        uint256 pricingCount,
        bool useSplitProcessor,
        bool usePostHook,
        bool useMerkleProof
    ) private returns (bytes32 activationId) {
        NamespaceTypes.ActivationConfig memory config = NamespaceTypes.ActivationConfig({
            registry: IPermissionedRegistry(address(registry)),
            parentNode: keccak256("alice.eth"),
            resolver: address(0xBEEF),
            buyerRoleBitmap: BUYER_ROLES,
            policies: _policies(label, policyCount, useMerkleProof),
            pricingModules: _pricingModules(pricingCount),
            paymentModule: NamespaceTypes.ModuleConfig({
                module: address(erc20Payment),
                configData: abi.encode(
                    ERC20PaymentModule.Params({
                        token: pricingCount == 0 ? ERC20(address(0)) : token,
                        recipient: useSplitProcessor ? address(splitProcessor) : accounts.treasury.addr
                    })
                )
            }),
            processor: _processor(useSplitProcessor),
            postHooks: _postHooks(usePostHook)
        });

        vm.prank(accounts.alice.addr);
        activationId = controller.activate(config);
    }

    function _policies(string memory label, uint256 count, bool useMerkleProof)
        private
        view
        returns (NamespaceTypes.ModuleConfig[] memory policies)
    {
        policies = new NamespaceTypes.ModuleConfig[](count);
        if (count > 0) {
            policies[0] = NamespaceTypes.ModuleConfig({
                module: address(saleWindowPolicy),
                configData: abi.encode(SaleWindowPolicy.Params({startTime: 0, endTime: 0}))
            });
        }
        if (count > 1) {
            policies[1] = NamespaceTypes.ModuleConfig({
                module: address(labelLengthPolicy),
                configData: abi.encode(LabelLengthPolicy.Params({minLength: 3, maxLength: 32}))
            });
        }
        if (count > 2) {
            policies[2] = NamespaceTypes.ModuleConfig({
                module: address(erc20GatePolicy),
                configData: abi.encode(ERC20BalanceGatePolicy.Params({token: token, minBalance: 100 ether}))
            });
        }
        if (count > 3) {
            bytes32 reservationRoot =
                reservationPolicy.leaf(keccak256(bytes(label)), accounts.buyer.addr, uint64(block.timestamp + 1 days));
            policies[3] = NamespaceTypes.ModuleConfig({
                module: address(reservationPolicy),
                configData: abi.encode(ReservationPolicy.Params({reservationRoot: reservationRoot}))
            });
        }
        if (count > 4) {
            bytes32 root = useMerkleProof
                ? _hashPair(_accountLabelLeaf(accounts.buyer.addr, keccak256(bytes(label))), keccak256("sibling"))
                : bytes32(0);
            policies[4] = NamespaceTypes.ModuleConfig({
                module: address(whitelistPolicy),
                configData: abi.encode(
                    MerkleWhitelistPolicy.Params({
                        mintRoot: root, renewRoot: bytes32(0), leafMode: MerkleWhitelistPolicy.LeafMode.ACCOUNT_LABEL
                    })
                )
            });
        }
    }

    function _pricingModules(uint256 count) private view returns (NamespaceTypes.ModuleConfig[] memory pricingModules) {
        pricingModules = new NamespaceTypes.ModuleConfig[](count);
        if (count > 0) {
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
        }
        if (count > 1) {
            uint128[] memory mintRates = new uint128[](9);
            mintRates[8] = 1 gwei;
            uint128[] memory renewRates = new uint128[](1);
            renewRates[0] = 1 gwei;
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
        }
    }

    function _processor(bool useSplitProcessor) private view returns (NamespaceTypes.ModuleConfig memory processor) {
        if (!useSplitProcessor) {
            return NamespaceTypes.ModuleConfig({module: address(noopProcessor), configData: ""});
        }

        ERC20SplitProcessor.Split[] memory splits = new ERC20SplitProcessor.Split[](2);
        splits[0] = ERC20SplitProcessor.Split({recipient: accounts.alice.addr, bps: 7500});
        splits[1] = ERC20SplitProcessor.Split({recipient: accounts.treasury.addr, bps: 2500});
        processor = NamespaceTypes.ModuleConfig({module: address(splitProcessor), configData: abi.encode(splits)});
    }

    function _postHooks(bool usePostHook) private view returns (NamespaceTypes.ModuleConfig[] memory postHooks) {
        postHooks = new NamespaceTypes.ModuleConfig[](usePostHook ? 1 : 0);
        if (usePostHook) {
            postHooks[0] = NamespaceTypes.ModuleConfig({module: address(postHook), configData: ""});
        }
    }

    function _runtimeData(uint256 policyCount, uint256 pricingCount, bool useMerkleProof, bool usePostHook)
        private
        view
        returns (NamespaceTypes.RuntimeData memory runtimeData)
    {
        runtimeData.policyData = new bytes[](policyCount);
        runtimeData.pricingData = new bytes[](pricingCount);
        runtimeData.paymentData = "";
        runtimeData.processorData = "";
        runtimeData.postHookData = new bytes[](usePostHook ? 1 : 0);

        if (policyCount > 3) {
            runtimeData.policyData[3] = abi.encode(
                ReservationPolicy.ProofData({
                    account: accounts.buyer.addr, expiry: uint64(block.timestamp + 1 days), proof: new bytes32[](0)
                })
            );
        }
        if (policyCount > 4 && useMerkleProof) {
            bytes32[] memory proof = new bytes32[](1);
            proof[0] = keccak256("sibling");
            runtimeData.policyData[4] = abi.encode(proof);
        }
        if (usePostHook) {
            runtimeData.postHookData[0] = hex"b001";
        }
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
