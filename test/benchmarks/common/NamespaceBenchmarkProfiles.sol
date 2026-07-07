// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {IAggregatorV3} from "src/interfaces/IAggregatorV3.sol";
import {ERC20SplitPaymentModule} from "src/modules/payment/ERC20SplitPaymentModule.sol";
import {LabelClassRule} from "src/modules/rules/LabelClassRule.sol";
import {ReservationRule} from "src/modules/rules/ReservationRule.sol";
import {SaleWindowRule} from "src/modules/rules/SaleWindowRule.sol";
import {USDOracleRule} from "src/modules/rules/USDOracleRule.sol";
import {WhitelistRule} from "src/modules/rules/WhitelistRule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceBenchmarkBase} from "test/benchmarks/common/NamespaceBenchmarkBase.sol";

/// @notice Shared profile configuration used by direct rule, payment, hook, and registry benchmarks.
abstract contract NamespaceBenchmarkProfiles is NamespaceBenchmarkBase {
    bytes internal reservationProof10;
    bytes internal reservationProof100;
    bytes internal reservationProof1000;
    bytes internal whitelistProof10;
    bytes internal whitelistProof100;
    bytes internal whitelistProof1000;
    bytes internal oneResolverWrite;
    bytes internal threeResolverWrites;
    bytes internal fiveResolverWrites;
    bytes internal setAddrOverride;

    bytes32 internal profileSaleWindowBoundedId;
    bytes32 internal profileReservation10Id;
    bytes32 internal profileReservation100Id;
    bytes32 internal profileReservation1000Id;
    bytes32 internal profileWhitelist10Id;
    bytes32 internal profileWhitelist100Id;
    bytes32 internal profileWhitelist1000Id;
    bytes32 internal profileFixedLength5Id;
    bytes32 internal profileFixedLength20Id;
    bytes32 internal profileLengthPremium5Id;
    bytes32 internal profileLengthPremium20Id;
    bytes32 internal profileLabelClassNumberId;
    bytes32 internal profileLabelClassLetterId;
    bytes32 internal profileLabelClassEmojiId;
    bytes32 internal profileUsdOracleId;
    bytes32 internal profileSplit2Id;
    bytes32 internal profileSplit3Id;
    bytes32 internal profileSplit5Id;

    NamespaceTypes.MintContext internal profileDefaultMintCtx;
    NamespaceTypes.MintContext internal profileFullStackMintCtx;
    NamespaceTypes.MintContext internal profileSetAddrMintCtx;
    NamespaceTypes.Price internal profileTokenPrice;

    function setUp() public virtual override {
        super.setUp();

        MintScenario memory defaultScenario =
            _prepareMintScenario("default", _threeRulesConfig(false, false), _runtimeData(3, 0));
        MintScenario memory fullStackScenario = _prepareMintScenario(
            "12345", _allRulesConfig("12345", 1000, 1000, 5), _allRulesRuntimeData("12345", 1000, 1000, 5)
        );

        reservationProof10 = abi.encode(_reservationClaim("profile", 10));
        reservationProof100 = abi.encode(_reservationClaim("profile", 100));
        reservationProof1000 = abi.encode(_reservationClaim("profile", 1000));
        whitelistProof10 = abi.encode(_whitelistClaim("profile", 10));
        whitelistProof100 = abi.encode(_whitelistClaim("profile", 100));
        whitelistProof1000 = abi.encode(_whitelistClaim("profile", 1000));
        oneResolverWrite = _packedResolverOverrides(1);
        threeResolverWrites = _packedResolverOverrides(3);
        fiveResolverWrites = _packedResolverOverrides(5);
        setAddrOverride = abi.encode(accounts.alice.addr);

        _configureProfileRules();
        _configureProfileSplits();

        profileDefaultMintCtx = _mintCtx(defaultScenario.activationId, "default");
        profileFullStackMintCtx = _mintCtx(fullStackScenario.activationId, "12345");
        profileSetAddrMintCtx = _mintCtx(fullStackScenario.activationId, "12345");
        profileSetAddrMintCtx.resolver = address(setAddrResolver);
        profileTokenPrice = NamespaceTypes.Price({token: address(token), amount: 100 ether});
    }

    function _configureProfileRules() private {
        profileSaleWindowBoundedId = keccak256("profile-sale-window-bounded");
        profileReservation10Id = keccak256(abi.encode("profile-reservation", uint256(10)));
        profileReservation100Id = keccak256(abi.encode("profile-reservation", uint256(100)));
        profileReservation1000Id = keccak256(abi.encode("profile-reservation", uint256(1000)));
        profileWhitelist10Id = keccak256(abi.encode("profile-whitelist", uint256(10)));
        profileWhitelist100Id = keccak256(abi.encode("profile-whitelist", uint256(100)));
        profileWhitelist1000Id = keccak256(abi.encode("profile-whitelist", uint256(1000)));
        profileFixedLength5Id = keccak256(abi.encode("profile-fixed-length", uint256(5)));
        profileFixedLength20Id = keccak256(abi.encode("profile-fixed-length", uint256(20)));
        profileLengthPremium5Id = keccak256(abi.encode("profile-length-premium", uint256(5)));
        profileLengthPremium20Id = keccak256(abi.encode("profile-length-premium", uint256(20)));
        profileLabelClassNumberId = keccak256("profile-label-class-number");
        profileLabelClassLetterId = keccak256("profile-label-class-letter");
        profileLabelClassEmojiId = keccak256("profile-label-class-emoji");
        profileUsdOracleId = keccak256("profile-usd-oracle");

        vm.startPrank(address(controller));
        saleWindowRule.configure(
            profileSaleWindowBoundedId,
            abi.encode(SaleWindowRule.Params({startTime: uint64(block.timestamp), endTime: _reservationExpiry()}))
        );
        reservationRule.configure(profileReservation10Id, abi.encode(_reservationParams("profile", 10)));
        reservationRule.configure(profileReservation100Id, abi.encode(_reservationParams("profile", 100)));
        reservationRule.configure(profileReservation1000Id, abi.encode(_reservationParams("profile", 1000)));
        whitelistRule.configure(profileWhitelist10Id, abi.encode(_whitelistParams("profile", 10)));
        whitelistRule.configure(profileWhitelist100Id, abi.encode(_whitelistParams("profile", 100)));
        whitelistRule.configure(profileWhitelist1000Id, abi.encode(_whitelistParams("profile", 1000)));
        fixedPriceRule.configure(profileFixedLength5Id, abi.encode(_fixedPriceParams(5)));
        fixedPriceRule.configure(profileFixedLength20Id, abi.encode(_fixedPriceParams(20)));
        lengthPremiumRule.configure(profileLengthPremium5Id, abi.encode(_lengthPremiumParams(5)));
        lengthPremiumRule.configure(profileLengthPremium20Id, abi.encode(_lengthPremiumParams(20)));
        labelClassRule.configure(
            profileLabelClassNumberId, abi.encode(_labelClassParams(LabelClassRule.LabelClass.NUMBER))
        );
        labelClassRule.configure(
            profileLabelClassLetterId, abi.encode(_labelClassParams(LabelClassRule.LabelClass.LETTER))
        );
        labelClassRule.configure(
            profileLabelClassEmojiId, abi.encode(_labelClassParams(LabelClassRule.LabelClass.EMOJI))
        );
        usdOracleRule.configure(profileUsdOracleId, abi.encode(_usdOracleParams()));
        vm.stopPrank();
    }

    function _configureProfileSplits() private {
        profileSplit2Id = keccak256("profile-split-2");
        profileSplit3Id = keccak256("profile-split-3");
        profileSplit5Id = keccak256("profile-split-5");

        vm.startPrank(address(controller));
        splitPayment.configure(profileSplit2Id, abi.encode(_splitParams(2)));
        splitPayment.configure(profileSplit3Id, abi.encode(_splitParams(3)));
        splitPayment.configure(profileSplit5Id, abi.encode(_splitParams(5)));
        vm.stopPrank();
    }

    function _reservationParams(string memory label, uint256 setSize)
        private
        view
        returns (ReservationRule.Params memory params)
    {
        params = ReservationRule.Params({
            root: _rootFor(reservationRule.leaf(_reservationClaim(label, setSize)), setSize)
        });
    }

    function _whitelistParams(string memory label, uint256 setSize)
        private
        view
        returns (WhitelistRule.Params memory params)
    {
        params = WhitelistRule.Params({
            mintRoot: _rootFor(whitelistRule.leaf(_whitelistClaim(label, setSize)), setSize), renewRoot: bytes32(0)
        });
    }

    function _labelClassParams(LabelClassRule.LabelClass labelClass)
        private
        view
        returns (LabelClassRule.Params memory params)
    {
        params = LabelClassRule.Params({
            token: address(token),
            labelClass: labelClass,
            requireMatch: true,
            mintAmount: 10 ether,
            renewAmount: 5 ether,
            priceOp: NamespaceTypes.PriceOp.ADD
        });
    }

    function _usdOracleParams() private view returns (USDOracleRule.Params memory params) {
        params = USDOracleRule.Params({
            token: address(token),
            oracle: IAggregatorV3(address(oracle)),
            tokenDecimals: 18,
            maxStaleness: 1 days,
            mintUsdPrice: 100e18,
            renewUsdPrice: 25e18,
            priceOp: NamespaceTypes.PriceOp.ADD
        });
    }

    function _splitParams(uint256 count) private view returns (ERC20SplitPaymentModule.Params memory params) {
        ERC20SplitPaymentModule.Split[] memory splits = new ERC20SplitPaymentModule.Split[](count);
        uint256 remaining = 10_000;
        for (uint256 i; i < count;) {
            uint16 bps = SafeCastLib.toUint16(i == count - 1 ? remaining : 10_000 / count);
            splits[i] = ERC20SplitPaymentModule.Split({recipient: _splitRecipient(i), bps: bps});
            remaining -= bps;
            unchecked {
                ++i;
            }
        }
        params = ERC20SplitPaymentModule.Params({token: address(token), splits: splits});
    }

    function _splitRecipient(uint256 index) private view returns (address) {
        if (index == 0) return accounts.alice.addr;
        if (index == 1) return accounts.treasury.addr;
        if (index == 2) return accounts.owner.addr;
        if (index == 3) return address(controller);
        return address(this);
    }
}
