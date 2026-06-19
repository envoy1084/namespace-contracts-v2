// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {ERC20SplitPaymentModule} from "src/modules/payment/ERC20SplitPaymentModule.sol";
import {FixedPriceRule} from "src/modules/rules/FixedPriceRule.sol";
import {LengthPremiumRule} from "src/modules/rules/LengthPremiumRule.sol";
import {NamespaceBenchmarkClaims} from "test/benchmarks/common/NamespaceBenchmarkClaims.sol";

/// @notice Pricing table and payment-module builders for benchmark scenarios.
abstract contract NamespaceBenchmarkPricing is NamespaceBenchmarkClaims {
    function _fixedPriceParams(uint256 lengthPriceCount) internal view returns (FixedPriceRule.Params memory params) {
        FixedPriceRule.LengthPrice[] memory lengthPrices = new FixedPriceRule.LengthPrice[](lengthPriceCount);
        for (uint256 i; i < lengthPriceCount;) {
            uint256 length = i + 1;
            // casting to `uint16` is safe because benchmark callers use small fixed tables.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint16 labelLength = uint16(length);
            // casting to `uint128` is safe because benchmark callers use small fixed tables.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint128 mintAmount = uint128(length * 25 ether);
            // casting to `uint128` is safe because benchmark callers use small fixed tables.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint128 renewAmount = uint128(length * 10 ether);
            lengthPrices[i] =
                FixedPriceRule.LengthPrice({length: labelLength, mintAmount: mintAmount, renewAmount: renewAmount});
            unchecked {
                ++i;
            }
        }
        params = FixedPriceRule.Params({
            token: address(token),
            defaultMintAmount: 100 ether,
            defaultRenewAmount: 50 ether,
            lengthPrices: lengthPrices
        });
    }

    function _lengthPremiumParams(uint256 bucketCount) internal view returns (LengthPremiumRule.Params memory params) {
        uint128[] memory mintRates = new uint128[](bucketCount);
        uint128[] memory renewRates = new uint128[](bucketCount);
        for (uint256 i; i < bucketCount;) {
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

    function _erc20PaymentModule() internal view returns (NamespaceTypes.ModuleConfig memory paymentModule) {
        paymentModule = NamespaceTypes.ModuleConfig({
            module: address(erc20Payment),
            configData: abi.encode(ERC20PaymentModule.Params({token: token, recipient: accounts.treasury.addr}))
        });
    }

    function _splitPaymentModule() internal view returns (NamespaceTypes.ModuleConfig memory paymentModule) {
        ERC20SplitPaymentModule.Split[] memory splits = new ERC20SplitPaymentModule.Split[](2);
        splits[0] = ERC20SplitPaymentModule.Split({recipient: accounts.alice.addr, bps: 7500});
        splits[1] = ERC20SplitPaymentModule.Split({recipient: accounts.treasury.addr, bps: 2500});
        paymentModule = NamespaceTypes.ModuleConfig({
            module: address(splitPayment),
            configData: abi.encode(ERC20SplitPaymentModule.Params({token: address(token), splits: splits}))
        });
    }

    function _noPaymentModule() internal pure returns (NamespaceTypes.ModuleConfig memory paymentModule) {
        paymentModule = NamespaceTypes.ModuleConfig({module: address(0), configData: ""});
    }

    function _noHooks() internal pure returns (NamespaceTypes.ModuleConfig[] memory postHooks) {
        postHooks = new NamespaceTypes.ModuleConfig[](0);
    }
}
