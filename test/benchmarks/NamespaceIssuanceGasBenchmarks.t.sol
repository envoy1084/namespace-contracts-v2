// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHCAFactoryBasic} from "@ensv2/hca/interfaces/IHCAFactoryBasic.sol";
import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {PermissionedResolverLib} from "@ensv2/resolver/libraries/PermissionedResolverLib.sol";
import {PermissionedResolver} from "@ensv2/resolver/PermissionedResolver.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {VerifiableFactory} from "lib/contracts-v2/contracts/lib/verifiable-factory/src/VerifiableFactory.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {SetAddrToBuyerHook} from "src/modules/hooks/SetAddrToBuyerHook.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {ERC20BalanceGatePolicy} from "src/modules/policies/ERC20BalanceGatePolicy.sol";
import {LabelLengthPolicy} from "src/modules/policies/LabelLengthPolicy.sol";
import {MerkleWhitelistPolicy} from "src/modules/policies/MerkleWhitelistPolicy.sol";
import {PausePolicy} from "src/modules/policies/PausePolicy.sol";
import {ReservationPolicy} from "src/modules/policies/ReservationPolicy.sol";
import {SaleWindowPolicy} from "src/modules/policies/SaleWindowPolicy.sol";
import {FixedPricePricing} from "src/modules/pricing/FixedPricePricing.sol";
import {LabelClassPricing} from "src/modules/pricing/LabelClassPricing.sol";
import {LengthBasedPricing} from "src/modules/pricing/LengthBasedPricing.sol";
import {OnlyEmojiPricing} from "src/modules/pricing/OnlyEmojiPricing.sol";
import {OnlyLetterPricing} from "src/modules/pricing/OnlyLetterPricing.sol";
import {OnlyNumberPricing} from "src/modules/pricing/OnlyNumberPricing.sol";
import {ERC20SplitProcessor} from "src/modules/processors/ERC20SplitProcessor.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

/// @notice Gas benchmarks for activation, minting, and individual module function costs.
/// @dev Run with: forge snapshot --match-path 'test/benchmarks/*.t.sol' --snap test/benchmarks/.gas-snapshot
contract NamespaceIssuanceGasBenchmarks is NamespaceSetUp {
    struct MintScenario {
        bytes32 activationId;
        string label;
        NamespaceTypes.RuntimeData runtimeData;
    }

    ERC20BalanceGatePolicy internal erc20GatePolicy;
    ReservationPolicy internal reservationPolicy;
    MerkleWhitelistPolicy internal whitelistPolicy;
    PausePolicy internal pausePolicy;
    LengthBasedPricing internal lengthPricing;
    OnlyEmojiPricing internal emojiPricing;
    OnlyNumberPricing internal numberPricing;
    OnlyLetterPricing internal letterPricing;
    ERC20SplitProcessor internal splitProcessor;
    SetAddrToBuyerHook internal resolverHook;
    PermissionedResolver internal resolver;

    MintScenario internal mintFree;
    MintScenario internal mintTwoPolicies;
    MintScenario internal mintThreePolicies;
    MintScenario internal mintReservation10;
    MintScenario internal mintReservation100;
    MintScenario internal mintReservation200;
    MintScenario internal mintWhitelist10;
    MintScenario internal mintWhitelist100;
    MintScenario internal mintWhitelist1000;
    MintScenario internal mintFixedPrice;
    MintScenario internal mintFixedFiveLengthRules;
    MintScenario internal mintLengthFiveRules;
    MintScenario internal mintEmojiOnly;
    MintScenario internal mintNumberOnly;
    MintScenario internal mintSplitProcessor;
    MintScenario internal mintResolverOneRecord;
    MintScenario internal mintResolverThreeRecords;
    MintScenario internal mintResolverFiveRecords;
    MintScenario internal mintFullStack;

    bytes32 internal profileActivationId;
    bytes32 internal profileFixedDefaultId;
    bytes32 internal profileFixedFiveRulesId;
    bytes32 internal profileLengthFiveRulesId;
    bytes32 internal profileEmojiId;
    bytes32 internal profileNumberId;
    bytes32 internal profileLetterId;
    bytes32 internal profileReservation10Id;
    bytes32 internal profileReservation100Id;
    bytes32 internal profileReservation200Id;
    bytes32 internal profileWhitelist10Id;
    bytes32 internal profileWhitelist100Id;
    bytes32 internal profileWhitelist1000Id;
    NamespaceTypes.MintContext internal profileMintCtx;
    NamespaceTypes.Price internal profileZeroPrice;
    NamespaceTypes.Price internal profileTokenPrice;
    bytes internal reservationProof10;
    bytes internal reservationProof100;
    bytes internal reservationProof200;
    bytes internal whitelistProof10;
    bytes internal whitelistProof100;
    bytes internal whitelistProof1000;

    function setUp() public override {
        super.setUp();

        erc20GatePolicy = ERC20BalanceGatePolicy(_deployModule(address(new ERC20BalanceGatePolicy())));
        reservationPolicy = ReservationPolicy(_deployModule(address(new ReservationPolicy())));
        whitelistPolicy = MerkleWhitelistPolicy(_deployModule(address(new MerkleWhitelistPolicy())));
        pausePolicy = PausePolicy(_deployModule(address(new PausePolicy())));
        lengthPricing = LengthBasedPricing(_deployModule(address(new LengthBasedPricing())));
        emojiPricing = OnlyEmojiPricing(_deployModule(address(new OnlyEmojiPricing())));
        numberPricing = OnlyNumberPricing(_deployModule(address(new OnlyNumberPricing())));
        letterPricing = OnlyLetterPricing(_deployModule(address(new OnlyLetterPricing())));
        splitProcessor = ERC20SplitProcessor(_deployModule(address(new ERC20SplitProcessor())));
        resolverHook = SetAddrToBuyerHook(_deployModule(address(new SetAddrToBuyerHook())));
        resolver = _deployResolver(address(resolverHook), PermissionedResolverLib.ROLE_SET_ADDR);

        _approveBenchmarkModules();

        token.mint(address(splitProcessor), 1_000_000 ether);
        vm.prank(accounts.buyer.addr);
        token.approve(address(erc20Payment), type(uint256).max);

        mintFree = _prepareMintScenario("free", 0, 0, 0, 0, 0, false, false, false, false);
        mintTwoPolicies = _prepareMintScenario("twopolicy", 2, 0, 0, 0, 0, false, false, false, false);
        mintThreePolicies = _prepareMintScenario("threepolicy", 3, 0, 0, 0, 0, false, false, false, false);
        mintReservation10 = _prepareMintScenario("reserved10", 4, 10, 0, 0, 0, false, false, true, false);
        mintReservation100 = _prepareMintScenario("reserved100", 4, 100, 0, 0, 0, false, false, true, false);
        mintReservation200 = _prepareMintScenario("reserved200", 4, 200, 0, 0, 0, false, false, true, false);
        mintWhitelist10 = _prepareMintScenario("white10", 5, 0, 10, 0, 0, false, false, false, true);
        mintWhitelist100 = _prepareMintScenario("white100", 5, 0, 100, 0, 0, false, false, false, true);
        mintWhitelist1000 = _prepareMintScenario("white1000", 5, 0, 1000, 0, 0, false, false, false, true);
        mintFixedPrice = _prepareMintScenario("fixedpay", 0, 0, 0, 1, 0, false, false, false, false);
        mintFixedFiveLengthRules = _prepareMintScenario("fixedrules", 0, 0, 0, 2, 0, false, false, false, false);
        mintLengthFiveRules = _prepareMintScenario("lengthrules", 2, 0, 0, 3, 0, false, false, false, false);
        mintEmojiOnly = _prepareMintScenario(unicode"🔥", 0, 0, 0, 4, 0, false, false, false, false);
        mintNumberOnly = _prepareMintScenario("12345", 0, 0, 0, 5, 0, false, false, false, false);
        mintSplitProcessor = _prepareMintScenario("splitpay", 3, 0, 0, 1, 0, true, false, false, false);
        mintResolverOneRecord = _prepareMintScenario("resolve1", 0, 0, 0, 0, 1, false, true, false, false);
        mintResolverThreeRecords = _prepareMintScenario("resolve3", 0, 0, 0, 0, 3, false, true, false, false);
        mintResolverFiveRecords = _prepareMintScenario("resolve5", 0, 0, 0, 0, 5, false, true, false, false);
        mintFullStack = _prepareMintScenario("fullstack", 5, 1000, 1000, 6, 5, true, true, true, true);

        _configureProfileModules();
    }

    /*//////////////////////////////////////////////////////////////
                           ACTIVATION BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testBenchmark_activation_00_freeNoPolicies() public {
        _activate("actfree", 0, 0, 0, 0, 0, false, false, false, false);
    }

    function testBenchmark_activation_01_twoPoliciesSaleAndLength() public {
        _activate("acttwo", 2, 0, 0, 0, 0, false, false, false, false);
    }

    function testBenchmark_activation_02_threePoliciesWithERC20Gate() public {
        _activate("actthree", 3, 0, 0, 0, 0, false, false, false, false);
    }

    function testBenchmark_activation_03_fourPoliciesReservation10() public {
        _activate("actres10", 4, 10, 0, 0, 0, false, false, true, false);
    }

    function testBenchmark_activation_04_fourPoliciesReservation100() public {
        _activate("actres100", 4, 100, 0, 0, 0, false, false, true, false);
    }

    function testBenchmark_activation_05_fourPoliciesReservation200() public {
        _activate("actres200", 4, 200, 0, 0, 0, false, false, true, false);
    }

    function testBenchmark_activation_06_fivePoliciesWhitelist10() public {
        _activate("actwhite10", 5, 0, 10, 0, 0, false, false, false, true);
    }

    function testBenchmark_activation_07_fivePoliciesWhitelist100() public {
        _activate("actwhite100", 5, 0, 100, 0, 0, false, false, false, true);
    }

    function testBenchmark_activation_08_fivePoliciesWhitelist1000() public {
        _activate("actwhite1000", 5, 0, 1000, 0, 0, false, false, false, true);
    }

    function testBenchmark_activation_09_fixedPriceFiveLengthRules() public {
        _activate("actfixedrules", 0, 0, 0, 2, 0, false, false, false, false);
    }

    function testBenchmark_activation_10_lengthBasedFiveRules() public {
        _activate("actlength", 0, 0, 0, 3, 0, false, false, false, false);
    }

    function testBenchmark_activation_11_emojiOnlyPricing() public {
        _activate("actemoji", 0, 0, 0, 4, 0, false, false, false, false);
    }

    function testBenchmark_activation_12_numberOnlyPricing() public {
        _activate("actnumber", 0, 0, 0, 5, 0, false, false, false, false);
    }

    function testBenchmark_activation_13_allPoliciesPricingSplitFiveHooks() public {
        _activate("actall", 5, 1000, 1000, 6, 5, true, true, true, true);
    }

    /*//////////////////////////////////////////////////////////////
                             MINT BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testBenchmark_mint_00_freeNoPolicies() public {
        _mint(mintFree);
    }

    function testBenchmark_mint_01_twoPoliciesSaleAndLength() public {
        _mint(mintTwoPolicies);
    }

    function testBenchmark_mint_02_threePoliciesWithERC20Gate() public {
        _mint(mintThreePolicies);
    }

    function testBenchmark_mint_03_reservation10Proof() public {
        _mint(mintReservation10);
    }

    function testBenchmark_mint_04_reservation100Proof() public {
        _mint(mintReservation100);
    }

    function testBenchmark_mint_05_reservation200Proof() public {
        _mint(mintReservation200);
    }

    function testBenchmark_mint_06_whitelist10Proof() public {
        _mint(mintWhitelist10);
    }

    function testBenchmark_mint_07_whitelist100Proof() public {
        _mint(mintWhitelist100);
    }

    function testBenchmark_mint_08_whitelist1000Proof() public {
        _mint(mintWhitelist1000);
    }

    function testBenchmark_mint_09_fixedPriceERC20() public {
        _mint(mintFixedPrice);
    }

    function testBenchmark_mint_10_fixedPriceFiveLengthRules() public {
        _mint(mintFixedFiveLengthRules);
    }

    function testBenchmark_mint_11_lengthBasedFiveRules() public {
        _mint(mintLengthFiveRules);
    }

    function testBenchmark_mint_12_emojiOnlyPricing() public {
        _mint(mintEmojiOnly);
    }

    function testBenchmark_mint_13_numberOnlyPricing() public {
        _mint(mintNumberOnly);
    }

    function testBenchmark_mint_14_erc20SplitProcessor() public {
        _mint(mintSplitProcessor);
    }

    function testBenchmark_mint_15_resolverOneRecord() public {
        _mint(mintResolverOneRecord);
    }

    function testBenchmark_mint_16_resolverThreeRecords() public {
        _mint(mintResolverThreeRecords);
    }

    function testBenchmark_mint_17_resolverFiveRecords() public {
        _mint(mintResolverFiveRecords);
    }

    function testBenchmark_mint_18_fullStackAllPoliciesPricingSplitFiveHooks() public {
        _mint(mintFullStack);
    }

    /*//////////////////////////////////////////////////////////////
                          MODULE PROFILING
    //////////////////////////////////////////////////////////////*/

    function testBenchmark_profile_policy_00_saleWindow_checkMint() public view {
        saleWindowPolicy.checkMint(profileMintCtx, "");
    }

    function testBenchmark_profile_policy_01_labelLength_checkMint() public view {
        labelLengthPolicy.checkMint(profileMintCtx, "");
    }

    function testBenchmark_profile_policy_02_erc20Gate_checkMint() public view {
        erc20GatePolicy.checkMint(profileMintCtx, "");
    }

    function testBenchmark_profile_policy_03_reservation10_checkMint() public view {
        reservationPolicy.checkMint(_mintCtx(profileReservation10Id, "profile"), reservationProof10);
    }

    function testBenchmark_profile_policy_04_reservation100_checkMint() public view {
        reservationPolicy.checkMint(_mintCtx(profileReservation100Id, "profile"), reservationProof100);
    }

    function testBenchmark_profile_policy_05_reservation200_checkMint() public view {
        reservationPolicy.checkMint(_mintCtx(profileReservation200Id, "profile"), reservationProof200);
    }

    function testBenchmark_profile_policy_06_whitelist10_checkMint() public view {
        whitelistPolicy.checkMint(_mintCtx(profileWhitelist10Id, "profile"), whitelistProof10);
    }

    function testBenchmark_profile_policy_07_whitelist100_checkMint() public view {
        whitelistPolicy.checkMint(_mintCtx(profileWhitelist100Id, "profile"), whitelistProof100);
    }

    function testBenchmark_profile_policy_08_whitelist1000_checkMint() public view {
        whitelistPolicy.checkMint(_mintCtx(profileWhitelist1000Id, "profile"), whitelistProof1000);
    }

    function testBenchmark_profile_policy_09_pausePolicy_checkMint() public view {
        pausePolicy.checkMint(profileMintCtx, "");
    }

    function testBenchmark_profile_pricing_00_fixedDefault_quoteMint() public view {
        fixedPricePricing.quoteMint(_mintCtx(profileFixedDefaultId, "profiledefault"), profileZeroPrice, "");
    }

    function testBenchmark_profile_pricing_01_fixedFiveLengthRules_quoteMint() public view {
        fixedPricePricing.quoteMint(_mintCtx(profileFixedFiveRulesId, "profilerules"), profileZeroPrice, "");
    }

    function testBenchmark_profile_pricing_02_lengthBasedFiveRules_quoteMint() public view {
        lengthPricing.quoteMint(_mintCtx(profileLengthFiveRulesId, "profilelength"), profileTokenPrice, "");
    }

    function testBenchmark_profile_pricing_03_emojiOnly_quoteMint() public view {
        emojiPricing.quoteMint(_mintCtx(profileEmojiId, unicode"🔥"), profileTokenPrice, "");
    }

    function testBenchmark_profile_pricing_04_numberOnly_quoteMint() public view {
        numberPricing.quoteMint(_mintCtx(profileNumberId, "12345"), profileTokenPrice, "");
    }

    function testBenchmark_profile_pricing_05_letterOnly_quoteMint() public view {
        letterPricing.quoteMint(_mintCtx(profileLetterId, "profileletter"), profileTokenPrice, "");
    }

    function testBenchmark_profile_payment_00_collectMintERC20() public {
        vm.prank(address(controller));
        erc20Payment.collectMint(profileMintCtx, profileTokenPrice, "");
    }

    function testBenchmark_profile_processor_00_noop_processMint() public {
        vm.prank(address(controller));
        noopProcessor.processMint(profileMintCtx, profileTokenPrice, "");
    }

    function testBenchmark_profile_processor_01_split_processMint() public {
        vm.prank(address(controller));
        splitProcessor.processMint(profileMintCtx, profileTokenPrice, "");
    }

    function testBenchmark_profile_hook_00_setAddrToBuyer_afterMint() public {
        vm.prank(address(controller));
        resolverHook.afterMint(profileMintCtx, 1, "");
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    function _prepareMintScenario(
        string memory label,
        uint256 policyCount,
        uint256 reservationSetSize,
        uint256 whitelistSetSize,
        uint256 pricingMode,
        uint256 resolverRecordCount,
        bool useSplitProcessor,
        bool useResolver,
        bool useReservation,
        bool useWhitelist
    ) private returns (MintScenario memory scenario) {
        scenario.activationId = _activate(
            label,
            policyCount,
            reservationSetSize,
            whitelistSetSize,
            pricingMode,
            resolverRecordCount,
            useSplitProcessor,
            useResolver,
            useReservation,
            useWhitelist
        );
        scenario.label = label;
        scenario.runtimeData =
            _runtimeData(label, policyCount, reservationSetSize, whitelistSetSize, pricingMode, resolverRecordCount);
    }

    function _activate(
        string memory label,
        uint256 policyCount,
        uint256 reservationSetSize,
        uint256 whitelistSetSize,
        uint256 pricingMode,
        uint256 resolverRecordCount,
        bool useSplitProcessor,
        bool useResolver,
        bool useReservation,
        bool useWhitelist
    ) private returns (bytes32 activationId) {
        NamespaceTypes.ActivationConfig memory config = NamespaceTypes.ActivationConfig({
            registry: IPermissionedRegistry(address(registry)),
            parentNode: keccak256("alice.eth"),
            resolver: useResolver ? address(resolver) : address(0xBEEF),
            buyerRoleBitmap: BUYER_ROLES,
            policies: _policies(label, policyCount, reservationSetSize, whitelistSetSize, useReservation, useWhitelist),
            pricingModules: _pricingModules(pricingMode),
            paymentModule: NamespaceTypes.ModuleConfig({
                module: address(erc20Payment),
                configData: abi.encode(
                    ERC20PaymentModule.Params({
                        token: pricingMode == 0 ? ERC20(address(0)) : token,
                        recipient: useSplitProcessor ? address(splitProcessor) : accounts.treasury.addr
                    })
                )
            }),
            processor: _processor(useSplitProcessor),
            postHooks: _postHooks(resolverRecordCount)
        });

        vm.prank(accounts.alice.addr);
        activationId = controller.activate(config);
    }

    function _policies(
        string memory label,
        uint256 count,
        uint256 reservationSetSize,
        uint256 whitelistSetSize,
        bool useReservation,
        bool useWhitelist
    ) private view returns (NamespaceTypes.ModuleConfig[] memory policies) {
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
                configData: abi.encode(LabelLengthPolicy.Params({minLength: 1, maxLength: 32}))
            });
        }
        if (count > 2) {
            policies[2] = NamespaceTypes.ModuleConfig({
                module: address(erc20GatePolicy),
                configData: abi.encode(ERC20BalanceGatePolicy.Params({token: token, minBalance: 100 ether}))
            });
        }
        if (count > 3) {
            uint256 setSize = useReservation ? reservationSetSize : 1;
            bytes32 leaf = reservationPolicy.leaf(keccak256(bytes(label)), accounts.buyer.addr, _reservationExpiry());
            policies[3] = NamespaceTypes.ModuleConfig({
                module: address(reservationPolicy),
                configData: abi.encode(ReservationPolicy.Params({reservationRoot: _rootFor(leaf, setSize)}))
            });
        }
        if (count > 4) {
            uint256 setSize = useWhitelist ? whitelistSetSize : 1;
            bytes32 leaf = _accountLabelLeaf(accounts.buyer.addr, keccak256(bytes(label)));
            policies[4] = NamespaceTypes.ModuleConfig({
                module: address(whitelistPolicy),
                configData: abi.encode(
                    MerkleWhitelistPolicy.Params({
                        mintRoot: _rootFor(leaf, setSize),
                        renewRoot: bytes32(0),
                        leafMode: MerkleWhitelistPolicy.LeafMode.ACCOUNT_LABEL
                    })
                )
            });
        }
    }

    function _pricingModules(uint256 mode) private view returns (NamespaceTypes.ModuleConfig[] memory pricingModules) {
        if (mode == 0) {
            return new NamespaceTypes.ModuleConfig[](0);
        }
        if (mode == 1) {
            pricingModules = new NamespaceTypes.ModuleConfig[](1);
            pricingModules[0] = _fixedPricingConfig(0);
            return pricingModules;
        }
        if (mode == 2) {
            pricingModules = new NamespaceTypes.ModuleConfig[](1);
            pricingModules[0] = _fixedPricingConfig(5);
            return pricingModules;
        }
        if (mode == 3) {
            pricingModules = new NamespaceTypes.ModuleConfig[](1);
            pricingModules[0] = _lengthPricingConfig(5);
            return pricingModules;
        }
        if (mode == 4 || mode == 5 || mode == 6) {
            pricingModules = new NamespaceTypes.ModuleConfig[](mode == 6 ? 3 : 1);
            pricingModules[0] = NamespaceTypes.ModuleConfig({
                module: mode == 4 ? address(emojiPricing) : mode == 5 ? address(numberPricing) : address(letterPricing),
                configData: abi.encode(
                    LabelClassPricing.Params({token: address(token), mintAmount: 10 ether, renewAmount: 5 ether})
                )
            });
            if (mode == 6) {
                pricingModules[1] = _fixedPricingConfig(5);
                pricingModules[2] = _lengthPricingConfig(5);
            }
        }
    }

    function _runtimeData(
        string memory label,
        uint256 policyCount,
        uint256 reservationSetSize,
        uint256 whitelistSetSize,
        uint256 pricingMode,
        uint256 resolverRecordCount
    ) private view returns (NamespaceTypes.RuntimeData memory runtimeData) {
        runtimeData.policyData = new bytes[](policyCount);
        runtimeData.pricingData = new bytes[](pricingMode == 0 ? 0 : pricingMode == 6 ? 3 : 1);
        runtimeData.paymentData = "";
        runtimeData.processorData = "";
        runtimeData.postHookData = new bytes[](resolverRecordCount);

        if (policyCount > 3) {
            runtimeData.policyData[3] = _reservationProof(label, reservationSetSize);
        }
        if (policyCount > 4) {
            runtimeData.policyData[4] = _whitelistProof(label, whitelistSetSize);
        }
        for (uint256 i; i < resolverRecordCount;) {
            runtimeData.postHookData[i] = i == 0 ? bytes("") : abi.encode(_resolverOverride(i));
            unchecked {
                ++i;
            }
        }
    }

    function _mint(MintScenario memory scenario) private {
        vm.prank(accounts.buyer.addr);
        uint256 tokenId = controller.mint(scenario.activationId, scenario.label, 365 days, scenario.runtimeData);
        IPermissionedRegistry.State memory state = registry.getState(tokenId);
        assertEq(uint256(state.status), uint256(IPermissionedRegistry.Status.REGISTERED));
        assertEq(registry.ownerOf(tokenId), accounts.buyer.addr);
    }

    function _configureProfileModules() private {
        profileActivationId = _activate("profile", 5, 1000, 1000, 6, 1, true, true, true, true);
        profileFixedDefaultId = _activate("profiledefault", 0, 0, 0, 1, 0, false, false, false, false);
        profileFixedFiveRulesId = _activate("profilerules", 0, 0, 0, 2, 0, false, false, false, false);
        profileLengthFiveRulesId = _activate("profilelength", 0, 0, 0, 3, 0, false, false, false, false);
        profileEmojiId = _activate(unicode"🔥", 0, 0, 0, 4, 0, false, false, false, false);
        profileNumberId = _activate("12345", 0, 0, 0, 5, 0, false, false, false, false);
        profileLetterId = _activate("profileletter", 0, 0, 0, 6, 0, false, false, false, false);
        profileReservation10Id = _activate("profile", 4, 10, 0, 0, 0, false, false, true, false);
        profileReservation100Id = _activate("profile", 4, 100, 0, 0, 0, false, false, true, false);
        profileReservation200Id = _activate("profile", 4, 200, 0, 0, 0, false, false, true, false);
        profileWhitelist10Id = _activate("profile", 5, 0, 10, 0, 0, false, false, false, true);
        profileWhitelist100Id = _activate("profile", 5, 0, 100, 0, 0, false, false, false, true);
        profileWhitelist1000Id = _activate("profile", 5, 0, 1000, 0, 0, false, false, false, true);
        profileMintCtx = _mintCtx(profileActivationId, "profile");
        profileZeroPrice = NamespaceTypes.Price({token: address(0), amount: 0});
        profileTokenPrice = NamespaceTypes.Price({token: address(token), amount: 10 ether});
        reservationProof10 = _reservationProof("profile", 10);
        reservationProof100 = _reservationProof("profile", 100);
        reservationProof200 = _reservationProof("profile", 200);
        whitelistProof10 = _whitelistProof("profile", 10);
        whitelistProof100 = _whitelistProof("profile", 100);
        whitelistProof1000 = _whitelistProof("profile", 1000);
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

    function _approveBenchmarkModules() private {
        bytes32 policyKind = controller.MODULE_KIND_POLICY();
        bytes32 pricingKind = controller.MODULE_KIND_PRICING();
        bytes32 processorKind = controller.MODULE_KIND_PROCESSOR();
        bytes32 postHookKind = controller.MODULE_KIND_POST_HOOK();

        vm.startPrank(accounts.owner.addr);
        controller.setModuleApproval(policyKind, address(erc20GatePolicy), true);
        controller.setModuleApproval(policyKind, address(reservationPolicy), true);
        controller.setModuleApproval(policyKind, address(whitelistPolicy), true);
        controller.setModuleApproval(policyKind, address(pausePolicy), true);
        controller.setModuleApproval(pricingKind, address(lengthPricing), true);
        controller.setModuleApproval(pricingKind, address(emojiPricing), true);
        controller.setModuleApproval(pricingKind, address(numberPricing), true);
        controller.setModuleApproval(pricingKind, address(letterPricing), true);
        controller.setModuleApproval(processorKind, address(splitProcessor), true);
        controller.setModuleApproval(postHookKind, address(resolverHook), true);
        vm.stopPrank();
    }

    function _fixedPricingConfig(uint256 lengthRuleCount) private view returns (NamespaceTypes.ModuleConfig memory) {
        FixedPricePricing.LengthPrice[] memory lengthPrices = new FixedPricePricing.LengthPrice[](lengthRuleCount);
        for (uint256 i; i < lengthRuleCount;) {
            lengthPrices[i] = FixedPricePricing.LengthPrice({
                length: SafeCastLib.toUint16(i + 1),
                mintAmount: SafeCastLib.toUint128((i + 1) * 1 ether),
                renewAmount: SafeCastLib.toUint128((i + 1) * 0.5 ether)
            });
            unchecked {
                ++i;
            }
        }
        return NamespaceTypes.ModuleConfig({
            module: address(fixedPricePricing),
            configData: abi.encode(
                FixedPricePricing.Params({
                    token: address(token),
                    defaultMintAmount: 100 ether,
                    defaultRenewAmount: 50 ether,
                    lengthPrices: lengthPrices
                })
            )
        });
    }

    function _lengthPricingConfig(uint256 ruleCount) private view returns (NamespaceTypes.ModuleConfig memory) {
        uint128[] memory mintRates = new uint128[](ruleCount);
        uint128[] memory renewRates = new uint128[](ruleCount);
        for (uint256 i; i < ruleCount;) {
            mintRates[i] = uint128((i + 1) * 1 gwei);
            renewRates[i] = uint128((i + 1) * 0.5 gwei);
            unchecked {
                ++i;
            }
        }
        return NamespaceTypes.ModuleConfig({
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

    function _processor(bool useSplitProcessor) private view returns (NamespaceTypes.ModuleConfig memory processor) {
        if (!useSplitProcessor) {
            return NamespaceTypes.ModuleConfig({module: address(noopProcessor), configData: ""});
        }

        ERC20SplitProcessor.Split[] memory splits = new ERC20SplitProcessor.Split[](2);
        splits[0] = ERC20SplitProcessor.Split({recipient: accounts.alice.addr, bps: 7500});
        splits[1] = ERC20SplitProcessor.Split({recipient: accounts.treasury.addr, bps: 2500});
        processor = NamespaceTypes.ModuleConfig({module: address(splitProcessor), configData: abi.encode(splits)});
    }

    function _postHooks(uint256 count) private view returns (NamespaceTypes.ModuleConfig[] memory postHooks) {
        postHooks = new NamespaceTypes.ModuleConfig[](count);
        for (uint256 i; i < count;) {
            postHooks[i] = NamespaceTypes.ModuleConfig({module: address(resolverHook), configData: ""});
            unchecked {
                ++i;
            }
        }
    }

    function _reservationProof(string memory label, uint256 setSize) private view returns (bytes memory) {
        return abi.encode(
            ReservationPolicy.ProofData({
                account: accounts.buyer.addr,
                expiry: _reservationExpiry(),
                proof: _proofFor(_reservationLeaf(label), setSize)
            })
        );
    }

    function _whitelistProof(string memory label, uint256 setSize) private view returns (bytes memory) {
        return abi.encode(_proofFor(_accountLabelLeaf(accounts.buyer.addr, keccak256(bytes(label))), setSize));
    }

    function _reservationLeaf(string memory label) private view returns (bytes32) {
        return reservationPolicy.leaf(keccak256(bytes(label)), accounts.buyer.addr, _reservationExpiry());
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

    function _resolverOverride(uint256 index) private view returns (address) {
        if (index == 1) return accounts.alice.addr;
        if (index == 2) return accounts.treasury.addr;
        if (index == 3) return accounts.owner.addr;
        return address(controller);
    }
}
