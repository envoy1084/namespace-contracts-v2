// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {IAggregatorV3} from "src/interfaces/IAggregatorV3.sol";
import {IPricingModule} from "src/interfaces/IPricingModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title USDOraclePricing
/// @notice Converts fixed USD-denominated mint and renewal prices into a payment token amount.
/// @dev `mintUsdPrice` and `renewUsdPrice` use 18 decimals. The oracle answer is expected to be
///      payment-token/USD, e.g. ETH/USD or USDC/USD, with `oracle.decimals()` decimals.
contract USDOraclePricing is NamespaceModule, IPricingModule {
    uint256 private constant _USD_DECIMALS = 1e18;

    /// @notice USD oracle pricing parameters for one activation.
    /// @param token Payment token. Use address(0) for native ETH.
    /// @param oracle Chainlink-compatible token/USD oracle.
    /// @param tokenDecimals Decimals of the payment token or native asset.
    /// @param maxStaleness Maximum age of the oracle answer in seconds.
    /// @param mintUsdPrice Mint price in USD with 18 decimals.
    /// @param renewUsdPrice Renewal price in USD with 18 decimals.
    struct Params {
        address token;
        IAggregatorV3 oracle;
        uint8 tokenDecimals;
        uint64 maxStaleness;
        uint128 mintUsdPrice;
        uint128 renewUsdPrice;
    }

    mapping(bytes32 activationId => Params params) public params;

    error ZeroOracle(bytes32 activationId);
    error InvalidTokenDecimals(uint8 tokenDecimals);
    error InvalidOraclePrice(int256 answer);
    error InvalidOracleRound(uint80 roundId, uint256 startedAt, uint80 answeredInRound);
    error StaleOraclePrice(uint256 updatedAt, uint256 maxStaleness, uint256 currentTime);
    error PaymentTokenMismatch(address expected, address actual);

    /// @notice Store USD pricing parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (address(decoded.oracle) == address(0)) {
            revert ZeroOracle(activationId);
        }
        if (decoded.tokenDecimals > 36) {
            revert InvalidTokenDecimals(decoded.tokenDecimals);
        }
        params[activationId] = decoded;
    }

    /// @inheritdoc IPricingModule
    function quoteMint(
        NamespaceTypes.MintContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        Params memory stored = params[ctx.activationId];
        price = _add(currentPrice, stored, stored.mintUsdPrice);
    }

    /// @inheritdoc IPricingModule
    function quoteRenew(
        NamespaceTypes.RenewContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        Params memory stored = params[ctx.activationId];
        price = _add(currentPrice, stored, stored.renewUsdPrice);
    }

    function _add(NamespaceTypes.Price calldata currentPrice, Params memory stored, uint256 usdAmount)
        private
        view
        returns (NamespaceTypes.Price memory price)
    {
        if (currentPrice.token != address(0) && currentPrice.token != stored.token) {
            revert PaymentTokenMismatch(currentPrice.token, stored.token);
        }

        price.token = stored.token;
        price.amount = currentPrice.amount + _quoteTokenAmount(stored, usdAmount);
    }

    function _quoteTokenAmount(Params memory stored, uint256 usdAmount) private view returns (uint256) {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            stored.oracle.latestRoundData();
        if (answer <= 0) {
            revert InvalidOraclePrice(answer);
        }
        if (startedAt == 0 || answeredInRound < roundId) {
            revert InvalidOracleRound(roundId, startedAt, answeredInRound);
        }
        uint256 currentTime = block.timestamp;
        if (stored.maxStaleness != 0 && currentTime > updatedAt + stored.maxStaleness) {
            revert StaleOraclePrice(updatedAt, stored.maxStaleness, currentTime);
        }

        uint256 tokenUnit = 10 ** stored.tokenDecimals;
        uint256 oracleUnit = 10 ** stored.oracle.decimals();
        uint256 numerator = usdAmount * tokenUnit * oracleUnit;
        uint256 denominator = SafeCastLib.toUint256(answer) * _USD_DECIMALS;
        return _ceilDiv(numerator, denominator);
    }

    function _ceilDiv(uint256 numerator, uint256 denominator) private pure returns (uint256) {
        return numerator == 0 ? 0 : (numerator - 1) / denominator + 1;
    }
}
