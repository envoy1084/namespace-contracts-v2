// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {IAggregatorV3} from "src/interfaces/IAggregatorV3.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceRule} from "src/modules/rules/NamespaceRule.sol";

/// @title USDOracleRule
/// @notice Converts USD-denominated mint and renewal prices into payment token amounts.
contract USDOracleRule is NamespaceRule {
    uint256 private constant _USD_DECIMALS = 1e18;
    uint8 private constant _MAX_SUPPORTED_DECIMALS = 18;

    /// @notice USD oracle rule parameters for one activation.
    /// @param token Payment token. Use address(0) for native ETH.
    /// @param oracle Chainlink-compatible token/USD oracle.
    /// @param tokenDecimals Decimals of the payment token or native asset.
    /// @param maxStaleness Maximum age of the oracle answer in seconds.
    /// @param mintUsdPrice Mint price in USD with 18 decimals.
    /// @param renewUsdPrice Renewal price in USD with 18 decimals.
    /// @param priceOp Price operation. Use SET_BASE for base USD pricing or ADD for a USD premium.
    struct Params {
        address token;
        IAggregatorV3 oracle;
        uint8 tokenDecimals;
        uint64 maxStaleness;
        uint128 mintUsdPrice;
        uint128 renewUsdPrice;
        NamespaceTypes.PriceOp priceOp;
    }

    mapping(bytes32 activationId => Params params) public params;

    error ZeroOracle(bytes32 activationId);
    error InvalidTokenDecimals(uint8 tokenDecimals);
    error InvalidOracleDecimals(uint8 oracleDecimals);
    error InvalidMaxStaleness();
    error InvalidOraclePrice(int256 answer);
    error InvalidOracleRound(uint80 roundId, uint256 startedAt, uint80 answeredInRound);
    error StaleOraclePrice(uint256 updatedAt, uint256 maxStaleness, uint256 currentTime);
    error InvalidUSDOraclePriceOp(NamespaceTypes.PriceOp priceOp);

    /// @notice Store USD oracle parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (address(decoded.oracle) == address(0)) {
            revert ZeroOracle(activationId);
        }
        if (decoded.maxStaleness == 0) {
            revert InvalidMaxStaleness();
        }
        if (decoded.tokenDecimals > _MAX_SUPPORTED_DECIMALS) {
            revert InvalidTokenDecimals(decoded.tokenDecimals);
        }
        uint8 oracleDecimals = decoded.oracle.decimals();
        if (oracleDecimals > _MAX_SUPPORTED_DECIMALS) {
            revert InvalidOracleDecimals(oracleDecimals);
        }
        _checkPriceOp(decoded.priceOp);
        params[activationId] = decoded;
    }

    /// @notice Evaluate rule.
    function evaluateMint(NamespaceTypes.MintContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        Params memory stored = params[ctx.activationId];
        output = _priceOutput(stored, stored.mintUsdPrice);
    }

    /// @notice Evaluate rule.
    function evaluateRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        Params memory stored = params[ctx.activationId];
        output = _priceOutput(stored, stored.renewUsdPrice);
    }

    function _priceOutput(Params memory stored, uint256 usdAmount)
        private
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        output.decision = NamespaceTypes.Decision.PASS;
        if (usdAmount == 0 || stored.priceOp == NamespaceTypes.PriceOp.NONE) {
            return output;
        }
        output.priceOp = stored.priceOp;
        output.token = stored.token;
        output.amount = _quoteTokenAmount(stored, usdAmount);
    }

    function _checkPriceOp(NamespaceTypes.PriceOp priceOp) private pure {
        if (
            priceOp != NamespaceTypes.PriceOp.NONE && priceOp != NamespaceTypes.PriceOp.SET_BASE
                && priceOp != NamespaceTypes.PriceOp.ADD && priceOp != NamespaceTypes.PriceOp.OVERRIDE
        ) {
            revert InvalidUSDOraclePriceOp(priceOp);
        }
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
        if (currentTime > updatedAt + stored.maxStaleness) {
            revert StaleOraclePrice(updatedAt, stored.maxStaleness, currentTime);
        }

        uint256 tokenUnit = 10 ** stored.tokenDecimals;
        uint8 oracleDecimals = stored.oracle.decimals();
        if (oracleDecimals > _MAX_SUPPORTED_DECIMALS) {
            revert InvalidOracleDecimals(oracleDecimals);
        }
        uint256 oracleUnit = 10 ** oracleDecimals;
        uint256 numerator = usdAmount * tokenUnit * oracleUnit;
        uint256 denominator = SafeCastLib.toUint256(answer) * _USD_DECIMALS;
        return _ceilDiv(numerator, denominator);
    }

    function _ceilDiv(uint256 numerator, uint256 denominator) private pure returns (uint256) {
        return numerator == 0 ? 0 : (numerator - 1) / denominator + 1;
    }
}
