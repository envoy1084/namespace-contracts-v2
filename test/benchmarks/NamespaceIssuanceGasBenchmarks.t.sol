// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHCAFactoryBasic} from "@ensv2/hca/interfaces/IHCAFactoryBasic.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {PermissionedResolverLib} from "@ensv2/resolver/libraries/PermissionedResolverLib.sol";
import {PermissionedResolver} from "@ensv2/resolver/PermissionedResolver.sol";
import {VerifiableFactory} from "lib/contracts-v2/contracts/lib/verifiable-factory/src/VerifiableFactory.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

import {IAggregatorV3} from "src/interfaces/IAggregatorV3.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {BatchSetAddrToBuyerHook} from "src/modules/hooks/BatchSetAddrToBuyerHook.sol";
import {ERC20SplitPaymentModule} from "src/modules/payment/ERC20SplitPaymentModule.sol";
import {FixedPriceRule} from "src/modules/rules/FixedPriceRule.sol";
import {LabelClassRule} from "src/modules/rules/LabelClassRule.sol";
import {LabelLengthRule} from "src/modules/rules/LabelLengthRule.sol";
import {LengthPremiumRule} from "src/modules/rules/LengthPremiumRule.sol";
import {ReservationRule} from "src/modules/rules/ReservationRule.sol";
import {SaleWindowRule} from "src/modules/rules/SaleWindowRule.sol";
import {TokenBalanceRule} from "src/modules/rules/TokenBalanceRule.sol";
import {USDOracleRule} from "src/modules/rules/USDOracleRule.sol";
import {WhitelistRule} from "src/modules/rules/WhitelistRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";
import {MockAggregatorV3} from "test/mocks/MockAggregatorV3.sol";

/// @notice Gas benchmarks for the rule-based Namespace minting architecture.
/// @dev Run with: forge snapshot --match-path 'test/benchmarks/*.t.sol' --snap test/benchmarks/.gas-snapshot
contract NamespaceIssuanceGasBenchmarks is NamespaceSetUp {
    struct MintScenario {
        bytes32 activationId;
        string label;
        NamespaceTypes.RuntimeData runtimeData;
    }

    TokenBalanceRule internal tokenBalanceRule;
    ReservationRule internal reservationRule;
    WhitelistRule internal whitelistRule;
    LengthPremiumRule internal lengthPremiumRule;
    LabelClassRule internal labelClassRule;
    USDOracleRule internal usdOracleRule;
    ERC20SplitPaymentModule internal splitPayment;
    BatchSetAddrToBuyerHook internal batchResolverHook;
    PermissionedResolver internal resolver;
    MockAggregatorV3 internal oracle;

    MintScenario internal mintFree;
    MintScenario internal mintDefault;
    MintScenario internal mintFullStack;
    MintScenario internal renewDefault;

    bytes internal reservationProof10;
    bytes internal reservationProof1000;
    bytes internal whitelistProof10;
    bytes internal whitelistProof1000;
    bytes internal fiveResolverWrites;
    bytes32 internal profileReservation10Id;
    bytes32 internal profileReservation1000Id;
    bytes32 internal profileWhitelist10Id;
    bytes32 internal profileWhitelist1000Id;
    bytes32 internal profileLabelClassId;
    bytes32 internal profileUsdOracleId;
    NamespaceTypes.MintContext internal profileDefaultMintCtx;
    NamespaceTypes.MintContext internal profileFullStackMintCtx;
    NamespaceTypes.Price internal profileTokenPrice;

    function setUp() public override {
        super.setUp();

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

        _approveBenchmarkModules();

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), type(uint256).max);
        token.approve(address(splitPayment), type(uint256).max);
        vm.stopPrank();

        mintFree = _prepareMintScenario("free", _freeActivationConfig(), _runtimeData(0, 0));
        mintDefault = _prepareMintScenario("default", _defaultActivationConfig(), _defaultRuntimeData());
        mintFullStack = _prepareFullStackScenario("fullstack", 1000, 1000);
        renewDefault = _prepareRenewScenario("renewal", _defaultActivationConfig(), _defaultRuntimeData());

        reservationProof10 = abi.encode(_reservationClaim("profile", 10));
        reservationProof1000 = abi.encode(_reservationClaim("profile", 1000));
        whitelistProof10 = abi.encode(_whitelistClaim("profile", 10));
        whitelistProof1000 = abi.encode(_whitelistClaim("profile", 1000));
        _configureProfileClaims();
        fiveResolverWrites = _packedResolverOverrides(5);
        profileDefaultMintCtx = _mintCtx(mintDefault.activationId, "default");
        profileFullStackMintCtx = _mintCtx(mintFullStack.activationId, "fullstack");
        profileTokenPrice = NamespaceTypes.Price({token: address(token), amount: 100 ether});
    }

    /*//////////////////////////////////////////////////////////////
                           ACTIVATION BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testBenchmark_activation_00_freeNoRules() public {
        _activate(_freeActivationConfig());
    }

    function testBenchmark_activation_01_defaultThreeRulesPaymentHook() public {
        _activate(_defaultActivationConfig());
    }

    function testBenchmark_activation_02_fullStackSevenRulesSplitPaymentFiveResolverWrites() public {
        _activate(_fullStackConfig("activatefull", 1000, 1000));
    }

    /*//////////////////////////////////////////////////////////////
                             MINT BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testBenchmark_mint_00_freeNoRules() public {
        _mint(mintFree);
    }

    function testBenchmark_mint_01_defaultThreeRulesERC20PaymentHook() public {
        _mint(mintDefault);
    }

    function testBenchmark_mint_02_fullStackRulesSplitPaymentFiveResolverWrites() public {
        _mint(mintFullStack);
    }

    function testBenchmark_renew_00_defaultThreeRulesERC20Payment() public {
        vm.prank(accounts.buyer.addr);
        controller.renew(renewDefault.activationId, renewDefault.label, 30 days, _defaultRuntimeData());
    }

    /*//////////////////////////////////////////////////////////////
                          MODULE PROFILING
    //////////////////////////////////////////////////////////////*/

    function testBenchmark_profile_rule_00_saleWindow_evaluateMint() public view {
        saleWindowRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_01_labelLength_evaluateMint() public view {
        labelLengthRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_02_fixedPrice_evaluateMint() public view {
        fixedPriceRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_03_lengthPremium_evaluateMint() public view {
        lengthPremiumRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_04_tokenBalanceDiscount_evaluateMint() public view {
        tokenBalanceRule.evaluateMint(profileFullStackMintCtx, "");
    }

    function testBenchmark_profile_rule_05_reservation10_evaluateMint() public view {
        reservationRule.evaluateMint(_mintCtx(profileReservation10Id, "profile"), reservationProof10);
    }

    function testBenchmark_profile_rule_06_reservation1000_evaluateMint() public view {
        reservationRule.evaluateMint(_mintCtx(profileReservation1000Id, "profile"), reservationProof1000);
    }

    function testBenchmark_profile_rule_07_whitelist10_evaluateMint() public view {
        whitelistRule.evaluateMint(_mintCtx(profileWhitelist10Id, "profile"), whitelistProof10);
    }

    function testBenchmark_profile_rule_08_whitelist1000_evaluateMint() public view {
        whitelistRule.evaluateMint(_mintCtx(profileWhitelist1000Id, "profile"), whitelistProof1000);
    }

    function testBenchmark_profile_rule_09_labelClassNumber_evaluateMint() public view {
        labelClassRule.evaluateMint(_mintCtx(profileLabelClassId, "12345"), "");
    }

    function testBenchmark_profile_rule_10_usdOracle_evaluateMint() public view {
        usdOracleRule.evaluateMint(_mintCtx(profileUsdOracleId, "usd"), "");
    }

    function testBenchmark_profile_payment_00_collectMintERC20() public {
        vm.prank(address(controller));
        erc20Payment.collectMint(profileDefaultMintCtx, profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_01_collectMintSplitERC20() public {
        vm.prank(address(controller));
        splitPayment.collectMint(profileFullStackMintCtx, profileTokenPrice, "");
    }

    function testBenchmark_profile_hook_00_recordingPostHook_afterMint() public {
        vm.prank(address(controller));
        postHook.afterMint(profileDefaultMintCtx, 1, "");
    }

    function testBenchmark_profile_hook_01_batchResolverHookFiveWrites_afterMint() public {
        vm.prank(address(controller));
        batchResolverHook.afterMint(profileFullStackMintCtx, 1, fiveResolverWrites);
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    function _prepareMintScenario(
        string memory label,
        NamespaceTypes.ActivationConfig memory config,
        NamespaceTypes.RuntimeData memory runtimeData
    ) private returns (MintScenario memory scenario) {
        scenario.activationId = _activate(config);
        scenario.label = label;
        scenario.runtimeData = runtimeData;
    }

    function _prepareFullStackScenario(string memory label, uint256 reservationSetSize, uint256 whitelistSetSize)
        private
        returns (MintScenario memory scenario)
    {
        scenario.activationId = _activate(_fullStackConfig(label, reservationSetSize, whitelistSetSize));
        scenario.label = label;
        scenario.runtimeData = _fullStackRuntimeData(label, reservationSetSize, whitelistSetSize);
    }

    function _prepareRenewScenario(
        string memory label,
        NamespaceTypes.ActivationConfig memory config,
        NamespaceTypes.RuntimeData memory runtimeData
    ) private returns (MintScenario memory scenario) {
        scenario = _prepareMintScenario(label, config, runtimeData);
        _mint(scenario);
    }

    function _activate(NamespaceTypes.ActivationConfig memory config) private returns (bytes32 activationId) {
        vm.prank(accounts.alice.addr);
        activationId = controller.activate(config);
    }

    function _mint(MintScenario memory scenario) private {
        vm.prank(accounts.buyer.addr);
        uint256 tokenId = controller.mint(scenario.activationId, scenario.label, 365 days, scenario.runtimeData);
        IPermissionedRegistry.State memory state = registry.getState(tokenId);
        assertEq(uint256(state.status), uint256(IPermissionedRegistry.Status.REGISTERED));
        assertEq(registry.ownerOf(tokenId), accounts.buyer.addr);
    }

    function _freeActivationConfig() private view returns (NamespaceTypes.ActivationConfig memory config) {
        config = NamespaceTypes.ActivationConfig({
            registry: IPermissionedRegistry(address(registry)),
            parentNode: keccak256("alice.eth"),
            resolver: address(0),
            buyerRoleBitmap: BUYER_ROLES,
            rules: new NamespaceTypes.RuleConfig[](0),
            paymentModule: NamespaceTypes.ModuleConfig({module: address(0), configData: ""}),
            postHooks: new NamespaceTypes.ModuleConfig[](0)
        });
    }

    function _fullStackConfig(string memory label, uint256 reservationSetSize, uint256 whitelistSetSize)
        private
        view
        returns (NamespaceTypes.ActivationConfig memory config)
    {
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](7);
        rules[0] = NamespaceTypes.RuleConfig({
            module: address(saleWindowRule),
            phase: NamespaceTypes.RulePhase.GUARD,
            configData: abi.encode(SaleWindowRule.Params({startTime: 0, endTime: 0}))
        });
        rules[1] = NamespaceTypes.RuleConfig({
            module: address(labelLengthRule),
            phase: NamespaceTypes.RulePhase.ELIGIBILITY,
            configData: abi.encode(LabelLengthRule.Params({minLength: 1, maxLength: 32}))
        });
        rules[2] = NamespaceTypes.RuleConfig({
            module: address(whitelistRule),
            phase: NamespaceTypes.RulePhase.ELIGIBILITY,
            configData: abi.encode(
                WhitelistRule.Params({
                    mintRoot: _rootFor(whitelistRule.leaf(_whitelistClaim(label, whitelistSetSize)), whitelistSetSize),
                    renewRoot: bytes32(0)
                })
            )
        });
        rules[3] = NamespaceTypes.RuleConfig({
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
        rules[4] = NamespaceTypes.RuleConfig({
            module: address(lengthPremiumRule),
            phase: NamespaceTypes.RulePhase.PREMIUM,
            configData: abi.encode(_lengthPremiumParams(5))
        });
        rules[5] = NamespaceTypes.RuleConfig({
            module: address(tokenBalanceRule),
            phase: NamespaceTypes.RulePhase.DISCOUNT,
            configData: abi.encode(
                TokenBalanceRule.Params({token: ERC20(address(token)), minBalance: 100 ether, discountBps: 500})
            )
        });
        rules[6] = NamespaceTypes.RuleConfig({
            module: address(reservationRule),
            phase: NamespaceTypes.RulePhase.OVERRIDE,
            configData: abi.encode(
                ReservationRule.Params({
                    root: _rootFor(
                        reservationRule.leaf(_reservationClaim(label, reservationSetSize)), reservationSetSize
                    )
                })
            )
        });

        NamespaceTypes.ModuleConfig[] memory postHooks = new NamespaceTypes.ModuleConfig[](1);
        postHooks[0] = NamespaceTypes.ModuleConfig({module: address(batchResolverHook), configData: ""});

        config = NamespaceTypes.ActivationConfig({
            registry: IPermissionedRegistry(address(registry)),
            parentNode: keccak256("alice.eth"),
            resolver: address(resolver),
            buyerRoleBitmap: BUYER_ROLES,
            rules: rules,
            paymentModule: _splitPaymentModule(),
            postHooks: postHooks
        });
    }

    function _runtimeData(uint256 ruleCount, uint256 postHookCount)
        private
        pure
        returns (NamespaceTypes.RuntimeData memory runtimeData)
    {
        runtimeData.ruleData = new bytes[](ruleCount);
        runtimeData.paymentData = "";
        runtimeData.postHookData = new bytes[](postHookCount);
    }

    function _fullStackRuntimeData(string memory label, uint256 reservationSetSize, uint256 whitelistSetSize)
        private
        view
        returns (NamespaceTypes.RuntimeData memory runtimeData)
    {
        runtimeData = _runtimeData(7, 1);
        runtimeData.ruleData[2] = abi.encode(_whitelistClaim(label, whitelistSetSize));
        runtimeData.ruleData[6] = abi.encode(_reservationClaim(label, reservationSetSize));
        runtimeData.postHookData[0] = _packedResolverOverrides(5);
    }

    function _splitPaymentModule() private view returns (NamespaceTypes.ModuleConfig memory paymentModule) {
        ERC20SplitPaymentModule.Split[] memory splits = new ERC20SplitPaymentModule.Split[](2);
        splits[0] = ERC20SplitPaymentModule.Split({recipient: accounts.alice.addr, bps: 7500});
        splits[1] = ERC20SplitPaymentModule.Split({recipient: accounts.treasury.addr, bps: 2500});
        paymentModule = NamespaceTypes.ModuleConfig({
            module: address(splitPayment),
            configData: abi.encode(ERC20SplitPaymentModule.Params({token: address(token), splits: splits}))
        });
    }

    function _lengthPremiumParams(uint256 ruleCount) private view returns (LengthPremiumRule.Params memory params) {
        uint128[] memory mintRates = new uint128[](ruleCount);
        uint128[] memory renewRates = new uint128[](ruleCount);
        for (uint256 i; i < ruleCount;) {
            mintRates[i] = uint128((i + 1) * 1 gwei);
            renewRates[i] = uint128((i + 1) * 0.5 gwei);
            unchecked {
                ++i;
            }
        }
        params = LengthPremiumRule.Params({
            token: address(token), mintPricePerSecondByLength: mintRates, renewPricePerSecondByLength: renewRates
        });
    }

    function _reservationClaim(string memory label, uint256 setSize)
        private
        view
        returns (ReservationRule.Claim memory claim)
    {
        claim = ReservationRule.Claim({
            labelHash: keccak256(bytes(label)),
            account: accounts.buyer.addr,
            startTime: 0,
            endTime: _reservationExpiry(),
            mintable: true,
            token: address(token),
            mintPrice: 1000 ether,
            renewPrice: 100 ether,
            priceOp: NamespaceTypes.PriceOp.OVERRIDE,
            proof: new bytes32[](0)
        });
        claim.proof = _proofFor(reservationRule.leaf(claim), setSize);
    }

    function _whitelistClaim(string memory label, uint256 setSize)
        private
        view
        returns (WhitelistRule.Claim memory claim)
    {
        claim = WhitelistRule.Claim({
            labelHash: keccak256(bytes(label)),
            account: accounts.buyer.addr,
            startTime: 0,
            endTime: _reservationExpiry(),
            mintable: true,
            token: address(0),
            mintPrice: 0,
            renewPrice: 0,
            discountBps: 0,
            priceOp: NamespaceTypes.PriceOp.NONE,
            proof: new bytes32[](0)
        });
        claim.proof = _proofFor(whitelistRule.leaf(claim), setSize);
    }

    function _mintCtx(bytes32 activationId, string memory label)
        private
        view
        returns (NamespaceTypes.MintContext memory)
    {
        return NamespaceTypes.MintContext({
            activationId: activationId,
            buyer: accounts.buyer.addr,
            payer: accounts.buyer.addr,
            registry: IPermissionedRegistry(address(registry)),
            parentNode: keccak256("alice.eth"),
            label: label,
            labelHash: keccak256(bytes(label)),
            duration: 365 days,
            expiry: uint64(block.timestamp + 365 days),
            resolver: address(resolver),
            buyerRoleBitmap: BUYER_ROLES
        });
    }

    function _renewCtx(bytes32 activationId, string memory label)
        private
        view
        returns (NamespaceTypes.RenewContext memory)
    {
        uint256 tokenId = uint256(keccak256(bytes(label)));
        return NamespaceTypes.RenewContext({
            activationId: activationId,
            payer: accounts.buyer.addr,
            registry: IPermissionedRegistry(address(registry)),
            parentNode: keccak256("alice.eth"),
            label: label,
            labelHash: bytes32(tokenId),
            tokenId: tokenId,
            duration: 30 days,
            currentExpiry: uint64(block.timestamp + 365 days),
            newExpiry: uint64(block.timestamp + 395 days)
        });
    }

    function _approveBenchmarkModules() private {
        bytes32 ruleKind = controller.MODULE_KIND_RULE();
        bytes32 paymentKind = controller.MODULE_KIND_PAYMENT();
        bytes32 postHookKind = controller.MODULE_KIND_POST_HOOK();

        vm.startPrank(accounts.owner.addr);
        controller.setModuleApproval(ruleKind, address(tokenBalanceRule), true);
        controller.setModuleApproval(ruleKind, address(reservationRule), true);
        controller.setModuleApproval(ruleKind, address(whitelistRule), true);
        controller.setModuleApproval(ruleKind, address(lengthPremiumRule), true);
        controller.setModuleApproval(ruleKind, address(labelClassRule), true);
        controller.setModuleApproval(ruleKind, address(usdOracleRule), true);
        controller.setModuleApproval(paymentKind, address(splitPayment), true);
        controller.setModuleApproval(postHookKind, address(batchResolverHook), true);
        vm.stopPrank();
    }

    function _configureProfileClaims() private {
        profileReservation10Id = keccak256(abi.encode("profile-reservation", uint256(10)));
        profileReservation1000Id = keccak256(abi.encode("profile-reservation", uint256(1000)));
        profileWhitelist10Id = keccak256(abi.encode("profile-whitelist", uint256(10)));
        profileWhitelist1000Id = keccak256(abi.encode("profile-whitelist", uint256(1000)));
        profileLabelClassId = keccak256("profile-label-class");
        profileUsdOracleId = keccak256("profile-usd-oracle");

        vm.startPrank(address(controller));
        reservationRule.configure(
            profileReservation10Id,
            abi.encode(
                ReservationRule.Params({root: _rootFor(reservationRule.leaf(_reservationClaim("profile", 10)), 10)})
            )
        );
        reservationRule.configure(
            profileReservation1000Id,
            abi.encode(
                ReservationRule.Params({root: _rootFor(reservationRule.leaf(_reservationClaim("profile", 1000)), 1000)})
            )
        );
        whitelistRule.configure(
            profileWhitelist10Id,
            abi.encode(
                WhitelistRule.Params({
                    mintRoot: _rootFor(whitelistRule.leaf(_whitelistClaim("profile", 10)), 10), renewRoot: bytes32(0)
                })
            )
        );
        whitelistRule.configure(
            profileWhitelist1000Id,
            abi.encode(
                WhitelistRule.Params({
                    mintRoot: _rootFor(whitelistRule.leaf(_whitelistClaim("profile", 1000)), 1000),
                    renewRoot: bytes32(0)
                })
            )
        );
        labelClassRule.configure(
            profileLabelClassId,
            abi.encode(
                LabelClassRule.Params({
                    token: address(token),
                    labelClass: LabelClassRule.LabelClass.NUMBER,
                    requireMatch: true,
                    mintAmount: 10 ether,
                    renewAmount: 5 ether,
                    priceOp: NamespaceTypes.PriceOp.ADD
                })
            )
        );
        usdOracleRule.configure(
            profileUsdOracleId,
            abi.encode(
                USDOracleRule.Params({
                    token: address(token),
                    oracle: IAggregatorV3(address(oracle)),
                    tokenDecimals: 18,
                    maxStaleness: 1 days,
                    mintUsdPrice: 100e18,
                    renewUsdPrice: 25e18,
                    priceOp: NamespaceTypes.PriceOp.ADD
                })
            )
        );
        vm.stopPrank();
    }

    function _rootFor(bytes32 leaf, uint256 setSize) private pure returns (bytes32 root) {
        root = leaf;
        bytes32[] memory proof = _proofFor(leaf, setSize);
        for (uint256 i; i < proof.length;) {
            root = _hashPair(root, proof[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _proofFor(bytes32 leaf, uint256 setSize) private pure returns (bytes32[] memory proof) {
        uint256 depth = _ceilLog2(setSize);
        proof = new bytes32[](depth);
        for (uint256 i; i < depth;) {
            proof[i] = keccak256(abi.encodePacked("sibling", leaf, i, setSize));
            unchecked {
                ++i;
            }
        }
    }

    function _ceilLog2(uint256 value) private pure returns (uint256 result) {
        if (value <= 1) {
            return 0;
        }
        uint256 n = value - 1;
        while (n != 0) {
            n >>= 1;
            ++result;
        }
    }

    function _reservationExpiry() private view returns (uint64) {
        return uint64(block.timestamp + 30 days);
    }

    function _deployResolver(address admin, uint256 roles) private returns (PermissionedResolver) {
        VerifiableFactory factory = new VerifiableFactory();
        PermissionedResolver resolverImpl = new PermissionedResolver(IHCAFactoryBasic(address(0)));
        bytes memory initData = abi.encodeCall(PermissionedResolver.initialize, (admin, roles));
        return PermissionedResolver(factory.deployProxy(address(resolverImpl), uint256(keccak256(initData)), initData));
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

    function _packedResolverOverrides(uint256 count) private view returns (bytes memory packed) {
        packed = new bytes(count * 20);
        for (uint256 i; i < count;) {
            address override_ = i == 0 ? address(0) : _resolverOverride(i);
            uint256 offset = 32 + i * 20;
            assembly ("memory-safe") {
                let word := mload(add(packed, offset))
                mstore(add(packed, offset), or(shl(96, override_), and(word, 0xffffffffffffffffffffffff)))
            }
            unchecked {
                ++i;
            }
        }
    }

    function _resolverOverride(uint256 index) private view returns (address) {
        if (index == 1) return accounts.alice.addr;
        if (index == 2) return accounts.treasury.addr;
        if (index == 3) return accounts.owner.addr;
        return address(controller);
    }
}
