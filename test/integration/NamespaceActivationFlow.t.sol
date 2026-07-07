// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20SplitPaymentModule} from "src/modules/payment/ERC20SplitPaymentModule.sol";
import {FixedPriceRule} from "src/modules/rules/FixedPriceRule.sol";
import {LengthPremiumRule} from "src/modules/rules/LengthPremiumRule.sol";
import {ReservationRule} from "src/modules/rules/ReservationRule.sol";
import {TokenBalanceRule} from "src/modules/rules/TokenBalanceRule.sol";
import {WhitelistRule} from "src/modules/rules/WhitelistRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract NamespaceActivationFlowTest is NamespaceSetUp {
    TokenBalanceRule internal tokenBalanceRule;
    ReservationRule internal reservationRule;
    WhitelistRule internal whitelistRule;
    LengthPremiumRule internal lengthPremiumRule;
    ERC20SplitPaymentModule internal splitPayment;

    function setUp() public override {
        super.setUp();
        tokenBalanceRule = TokenBalanceRule(_deployModule(address(new TokenBalanceRule())));
        reservationRule = ReservationRule(_deployModule(address(new ReservationRule())));
        whitelistRule = WhitelistRule(_deployModule(address(new WhitelistRule())));
        lengthPremiumRule = LengthPremiumRule(_deployModule(address(new LengthPremiumRule())));
        splitPayment = ERC20SplitPaymentModule(_deployModule(address(new ERC20SplitPaymentModule())));

        vm.startPrank(accounts.owner.addr);
        controller.setModuleApproval(controller.MODULE_KIND_RULE(), address(tokenBalanceRule), true);
        controller.setModuleApproval(controller.MODULE_KIND_RULE(), address(reservationRule), true);
        controller.setModuleApproval(controller.MODULE_KIND_RULE(), address(whitelistRule), true);
        controller.setModuleApproval(controller.MODULE_KIND_RULE(), address(lengthPremiumRule), true);
        controller.setModuleApproval(controller.MODULE_KIND_PAYMENT(), address(splitPayment), true);
        vm.stopPrank();
    }

    function test_mint_executesRulePaymentRegistryHookFlow() public {
        string memory label = "vip";
        bytes32 labelHash = keccak256(bytes(label));
        uint64 duration = 10;
        bytes32 activationId = _activateIntegration(labelHash);
        NamespaceTypes.RuntimeData memory runtimeData = _integrationRuntimeData(labelHash);

        uint256 quotedPrice = 100 ether + 20 ether;

        vm.prank(accounts.buyer.addr);
        tokenBalanceRule.recordBalance(activationId);
        vm.warp(block.timestamp + 1);

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(splitPayment), quotedPrice);
        uint256 tokenId = controller.mint(activationId, label, duration, runtimeData);
        vm.stopPrank();

        _assertMintedFlow(activationId, label, labelHash, tokenId);
    }

    function _assertMintedFlow(bytes32 activationId, string memory label, bytes32 labelHash, uint256 tokenId)
        private
        view
    {
        IPermissionedRegistry.State memory state = registry.getState(tokenId);
        assertEq(uint256(state.status), uint256(IPermissionedRegistry.Status.REGISTERED));
        assertEq(state.latestOwner, accounts.buyer.addr);
        assertEq(registry.ownerOf(tokenId), accounts.buyer.addr);
        assertEq(registry.getResolver(label), address(0xBEEF));
        assertEq(registry.roles(tokenId, accounts.buyer.addr), BUYER_ROLES);

        assertEq(token.balanceOf(accounts.alice.addr), 90 ether);
        assertEq(token.balanceOf(accounts.treasury.addr), 30 ether);

        assertEq(postHook.lastActivationId(), activationId);
        assertEq(postHook.lastBuyer(), accounts.buyer.addr);
        assertEq(postHook.lastLabelHash(), labelHash);
        assertEq(postHook.lastTokenId(), tokenId);
        assertEq(postHook.lastRuntimeData(), hex"cafe");
    }

    function _activateIntegration(bytes32 labelHash) private returns (bytes32 activationId) {
        ReservationRule.Claim memory reservationClaim = _reservationClaim(labelHash);
        WhitelistRule.Claim memory whitelistClaim = _whitelistClaim(labelHash);
        bytes32 whitelistRoot = _hashPair(whitelistRule.leaf(whitelistClaim), _whitelistSibling(labelHash));
        NamespaceTypes.ActivationConfig memory config =
            _integrationActivationConfig(reservationRule.leaf(reservationClaim), whitelistRoot);

        vm.prank(accounts.alice.addr);
        activationId = controller.activate(config);
    }

    function _integrationRuntimeData(bytes32 labelHash)
        private
        view
        returns (NamespaceTypes.RuntimeData memory runtimeData)
    {
        ReservationRule.Claim memory reservationClaim = _reservationClaim(labelHash);
        WhitelistRule.Claim memory whitelistClaim = _whitelistClaim(labelHash);
        bytes32[] memory whitelistProof = new bytes32[](1);
        whitelistProof[0] = _whitelistSibling(labelHash);
        whitelistClaim.proof = whitelistProof;

        runtimeData.ruleData = new bytes[](7);
        runtimeData.ruleData[3] = abi.encode(reservationClaim);
        runtimeData.ruleData[4] = abi.encode(whitelistClaim);
        runtimeData.postHookData = new bytes[](1);
        runtimeData.postHookData[0] = hex"cafe";
    }

    function _integrationActivationConfig(bytes32 reservationRoot, bytes32 whitelistRoot)
        private
        view
        returns (NamespaceTypes.ActivationConfig memory config)
    {
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](7);
        NamespaceTypes.ActivationConfig memory defaultConfig = _defaultActivationConfig();
        rules[0] = defaultConfig.rules[0];
        rules[1] = defaultConfig.rules[1];
        rules[2] = NamespaceTypes.RuleConfig({
            module: address(tokenBalanceRule),
            phase: NamespaceTypes.RulePhase.ELIGIBILITY,
            configData: abi.encode(
                TokenBalanceRule.Params({token: token, minBalance: 100 ether, discountBps: 0, minHoldTime: 1})
            )
        });
        rules[3] = NamespaceTypes.RuleConfig({
            module: address(reservationRule),
            phase: NamespaceTypes.RulePhase.ELIGIBILITY,
            configData: abi.encode(ReservationRule.Params({root: reservationRoot}))
        });
        rules[4] = NamespaceTypes.RuleConfig({
            module: address(whitelistRule),
            phase: NamespaceTypes.RulePhase.ELIGIBILITY,
            configData: abi.encode(WhitelistRule.Params({mintRoot: whitelistRoot, renewRoot: bytes32(0)}))
        });
        rules[5] = NamespaceTypes.RuleConfig({
            module: address(fixedPriceRule),
            phase: NamespaceTypes.RulePhase.BASE_PRICE,
            configData: abi.encode(
                FixedPriceRule.Params({
                    token: address(token),
                    defaultMintAmount: 100 ether,
                    defaultRenewAmount: 50 ether,
                    lengthPrices: new FixedPriceRule.LengthPrice[](0)
                })
            )
        });

        uint128[] memory mintRates = new uint128[](3);
        mintRates[0] = 0;
        mintRates[1] = 0;
        mintRates[2] = 2 ether;
        uint128[] memory renewRates = new uint128[](1);
        renewRates[0] = 1 ether;
        rules[6] = NamespaceTypes.RuleConfig({
            module: address(lengthPremiumRule),
            phase: NamespaceTypes.RulePhase.PREMIUM,
            configData: abi.encode(
                LengthPremiumRule.Params({
                    token: address(token),
                    mintPricePerSecondByLength: mintRates,
                    renewPricePerSecondByLength: renewRates
                })
            )
        });

        ERC20SplitPaymentModule.Split[] memory splits = new ERC20SplitPaymentModule.Split[](2);
        splits[0] = ERC20SplitPaymentModule.Split({recipient: accounts.alice.addr, bps: 7500});
        splits[1] = ERC20SplitPaymentModule.Split({recipient: accounts.treasury.addr, bps: 2500});

        NamespaceTypes.ModuleConfig[] memory postHooks = new NamespaceTypes.ModuleConfig[](1);
        postHooks[0] = NamespaceTypes.ModuleConfig({module: address(postHook), configData: ""});

        config = NamespaceTypes.ActivationConfig({
            registry: IPermissionedRegistry(address(registry)),
            parentNode: keccak256("alice.eth"),
            resolver: address(0xBEEF),
            buyerRoleBitmap: BUYER_ROLES,
            minDuration: 1,
            maxDuration: 365 days,
            rules: rules,
            paymentModule: NamespaceTypes.ModuleConfig({
                module: address(splitPayment),
                configData: abi.encode(ERC20SplitPaymentModule.Params({token: address(token), splits: splits}))
            }),
            postHooks: postHooks
        });
    }

    function _reservationClaim(bytes32 labelHash) private view returns (ReservationRule.Claim memory claim) {
        claim = ReservationRule.Claim({
            labelHash: labelHash,
            account: accounts.buyer.addr,
            startTime: 0,
            endTime: uint64(block.timestamp + 1 days),
            mintable: true,
            token: address(0),
            mintPrice: 0,
            renewPrice: 0,
            priceOp: NamespaceTypes.PriceOp.NONE,
            proof: new bytes32[](0)
        });
    }

    function _whitelistClaim(bytes32 labelHash) private view returns (WhitelistRule.Claim memory claim) {
        claim = WhitelistRule.Claim({
            labelHash: labelHash,
            account: accounts.buyer.addr,
            startTime: 0,
            endTime: 0,
            mintable: true,
            token: address(0),
            mintPrice: 0,
            renewPrice: 0,
            discountBps: 0,
            priceOp: NamespaceTypes.PriceOp.NONE,
            proof: new bytes32[](0)
        });
    }

    function _whitelistSibling(bytes32 labelHash) private view returns (bytes32) {
        WhitelistRule.Claim memory sibling = WhitelistRule.Claim({
            labelHash: labelHash,
            account: accounts.alice.addr,
            startTime: 0,
            endTime: 0,
            mintable: true,
            token: address(0),
            mintPrice: 0,
            renewPrice: 0,
            discountBps: 0,
            priceOp: NamespaceTypes.PriceOp.NONE,
            proof: new bytes32[](0)
        });
        return whitelistRule.leaf(sibling);
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
