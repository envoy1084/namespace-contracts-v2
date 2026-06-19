// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

import {IAggregatorV3} from "src/interfaces/IAggregatorV3.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {LabelClassRule} from "src/modules/rules/LabelClassRule.sol";
import {LabelLengthRule} from "src/modules/rules/LabelLengthRule.sol";
import {ReservationRule} from "src/modules/rules/ReservationRule.sol";
import {SaleWindowRule} from "src/modules/rules/SaleWindowRule.sol";
import {TokenBalanceRule} from "src/modules/rules/TokenBalanceRule.sol";
import {USDOracleRule} from "src/modules/rules/USDOracleRule.sol";
import {WhitelistRule} from "src/modules/rules/WhitelistRule.sol";
import {NamespaceBenchmarkPricing} from "test/benchmarks/common/NamespaceBenchmarkPricing.sol";

/// @notice Builds benchmark activation configs and runtime data.
abstract contract NamespaceBenchmarkScenarios is NamespaceBenchmarkPricing {
    function _freeActivationConfig() internal view returns (NamespaceTypes.ActivationConfig memory config) {
        config = _activationConfig(new NamespaceTypes.RuleConfig[](0), _noPaymentModule(), _noHooks(), address(0));
    }

    function _oneGuardFreeConfig() internal view returns (NamespaceTypes.ActivationConfig memory config) {
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](1);
        rules[0] = _saleWindowConfig();
        config = _activationConfig(rules, _noPaymentModule(), _noHooks(), address(0));
    }

    function _onePriceConfig(bool split) internal view returns (NamespaceTypes.ActivationConfig memory config) {
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](1);
        rules[0] = _fixedPriceConfig(0);
        config = _activationConfig(rules, split ? _splitPaymentModule() : _erc20PaymentModule(), _noHooks(), address(0));
    }

    function _twoRulesFreeConfig() internal view returns (NamespaceTypes.ActivationConfig memory config) {
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](2);
        rules[0] = _saleWindowConfig();
        rules[1] = _labelLengthConfig();
        config = _activationConfig(rules, _noPaymentModule(), _noHooks(), address(0));
    }

    function _threeRulesConfig(bool split, bool recordingHook)
        internal
        view
        returns (NamespaceTypes.ActivationConfig memory config)
    {
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](3);
        rules[0] = _saleWindowConfig();
        rules[1] = _labelLengthConfig();
        rules[2] = _fixedPriceConfig(0);

        NamespaceTypes.ModuleConfig[] memory postHooks =
            recordingHook ? new NamespaceTypes.ModuleConfig[](1) : _noHooks();
        if (recordingHook) {
            postHooks[0] = NamespaceTypes.ModuleConfig({module: address(postHook), configData: ""});
        }
        config = _activationConfig(
            rules,
            split ? _splitPaymentModule() : _erc20PaymentModule(),
            postHooks,
            recordingHook ? address(0xBEEF) : address(0)
        );
    }

    function _allRulesConfig(
        string memory label,
        uint256 reservationSetSize,
        uint256 whitelistSetSize,
        uint256 resolverWrites
    ) internal view returns (NamespaceTypes.ActivationConfig memory config) {
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](10);
        rules[0] = _pauseConfig();
        rules[1] = _saleWindowConfig();
        rules[2] = _labelLengthConfig();
        rules[3] = _whitelistConfig(label, whitelistSetSize);
        rules[4] = _fixedPriceConfig(3);
        rules[5] = _labelClassNumberConfig();
        rules[6] = _usdOracleConfig();
        rules[7] = _lengthPremiumConfig(12);
        rules[8] = _tokenBalanceConfig();
        rules[9] = _reservationConfig(label, reservationSetSize);

        NamespaceTypes.ModuleConfig[] memory postHooks =
            resolverWrites == 0 ? _noHooks() : new NamespaceTypes.ModuleConfig[](1);
        if (resolverWrites != 0) {
            postHooks[0] = NamespaceTypes.ModuleConfig({module: address(batchResolverHook), configData: ""});
        }

        config = _activationConfig(
            rules, _splitPaymentModule(), postHooks, resolverWrites == 0 ? address(0) : address(resolver)
        );
    }

    function _runtimeData(uint256 ruleCount, uint256 postHookCount)
        internal
        pure
        returns (NamespaceTypes.RuntimeData memory runtimeData)
    {
        runtimeData.ruleData = new bytes[](ruleCount);
        runtimeData.paymentData = "";
        runtimeData.postHookData = new bytes[](postHookCount);
    }

    function _allRulesRuntimeData(
        string memory label,
        uint256 reservationSetSize,
        uint256 whitelistSetSize,
        uint256 resolverWrites
    ) internal view returns (NamespaceTypes.RuntimeData memory runtimeData) {
        runtimeData = _runtimeData(10, resolverWrites == 0 ? 0 : 1);
        runtimeData.ruleData[3] = abi.encode(_whitelistClaim(label, whitelistSetSize));
        runtimeData.ruleData[9] = abi.encode(_reservationClaim(label, reservationSetSize));
        if (resolverWrites != 0) {
            runtimeData.postHookData[0] = _packedResolverOverrides(resolverWrites);
        }
    }

    function _mintCtx(bytes32 activationId, string memory label)
        internal
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

    function _activationConfig(
        NamespaceTypes.RuleConfig[] memory rules,
        NamespaceTypes.ModuleConfig memory paymentModule,
        NamespaceTypes.ModuleConfig[] memory postHooks,
        address resolver_
    ) internal view returns (NamespaceTypes.ActivationConfig memory config) {
        config = NamespaceTypes.ActivationConfig({
            registry: IPermissionedRegistry(address(registry)),
            parentNode: keccak256("alice.eth"),
            resolver: resolver_,
            buyerRoleBitmap: BUYER_ROLES,
            rules: rules,
            paymentModule: paymentModule,
            postHooks: postHooks
        });
    }

    function _pauseConfig() internal view returns (NamespaceTypes.RuleConfig memory) {
        return
            NamespaceTypes.RuleConfig({
                module: address(pauseRule), phase: NamespaceTypes.RulePhase.GUARD, configData: ""
            });
    }

    function _saleWindowConfig() internal view returns (NamespaceTypes.RuleConfig memory) {
        return NamespaceTypes.RuleConfig({
            module: address(saleWindowRule),
            phase: NamespaceTypes.RulePhase.GUARD,
            configData: abi.encode(SaleWindowRule.Params({startTime: 0, endTime: 0}))
        });
    }

    function _labelLengthConfig() internal view returns (NamespaceTypes.RuleConfig memory) {
        return NamespaceTypes.RuleConfig({
            module: address(labelLengthRule),
            phase: NamespaceTypes.RulePhase.ELIGIBILITY,
            configData: abi.encode(LabelLengthRule.Params({minLength: 1, maxLength: 32}))
        });
    }

    function _fixedPriceConfig(uint256 lengthPriceCount) internal view returns (NamespaceTypes.RuleConfig memory) {
        return NamespaceTypes.RuleConfig({
            module: address(fixedPriceRule),
            phase: NamespaceTypes.RulePhase.BASE_PRICE,
            configData: abi.encode(_fixedPriceParams(lengthPriceCount))
        });
    }

    function _labelClassNumberConfig() internal view returns (NamespaceTypes.RuleConfig memory) {
        return NamespaceTypes.RuleConfig({
            module: address(labelClassRule),
            phase: NamespaceTypes.RulePhase.PREMIUM,
            configData: abi.encode(
                LabelClassRule.Params({
                    token: address(token),
                    labelClass: LabelClassRule.LabelClass.NUMBER,
                    requireMatch: true,
                    mintAmount: 10 ether,
                    renewAmount: 5 ether,
                    priceOp: NamespaceTypes.PriceOp.ADD
                })
            )
        });
    }

    function _usdOracleConfig() internal view returns (NamespaceTypes.RuleConfig memory) {
        return NamespaceTypes.RuleConfig({
            module: address(usdOracleRule),
            phase: NamespaceTypes.RulePhase.PREMIUM,
            configData: abi.encode(
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
        });
    }

    function _lengthPremiumConfig(uint256 bucketCount) internal view returns (NamespaceTypes.RuleConfig memory) {
        return NamespaceTypes.RuleConfig({
            module: address(lengthPremiumRule),
            phase: NamespaceTypes.RulePhase.PREMIUM,
            configData: abi.encode(_lengthPremiumParams(bucketCount))
        });
    }

    function _tokenBalanceConfig() internal view returns (NamespaceTypes.RuleConfig memory) {
        return NamespaceTypes.RuleConfig({
            module: address(tokenBalanceRule),
            phase: NamespaceTypes.RulePhase.DISCOUNT,
            configData: abi.encode(
                TokenBalanceRule.Params({token: ERC20(address(token)), minBalance: 100 ether, discountBps: 500})
            )
        });
    }

    function _whitelistConfig(string memory label, uint256 setSize)
        internal
        view
        returns (NamespaceTypes.RuleConfig memory)
    {
        return NamespaceTypes.RuleConfig({
            module: address(whitelistRule),
            phase: NamespaceTypes.RulePhase.ELIGIBILITY,
            configData: abi.encode(
                WhitelistRule.Params({
                    mintRoot: _rootFor(whitelistRule.leaf(_whitelistClaim(label, setSize)), setSize),
                    renewRoot: bytes32(0)
                })
            )
        });
    }

    function _reservationConfig(string memory label, uint256 setSize)
        internal
        view
        returns (NamespaceTypes.RuleConfig memory)
    {
        return NamespaceTypes.RuleConfig({
            module: address(reservationRule),
            phase: NamespaceTypes.RulePhase.OVERRIDE,
            configData: abi.encode(
                ReservationRule.Params({
                    root: _rootFor(reservationRule.leaf(_reservationClaim(label, setSize)), setSize)
                })
            )
        });
    }
}
