// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {IProcessorModule} from "src/interfaces/IProcessorModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title ERC20SplitProcessor
/// @notice Splits ERC20 funds held by this processor according to activation-scoped basis points.
/// @dev Configure `ERC20PaymentModule.recipient` to this processor for split settlement.
contract ERC20SplitProcessor is NamespaceModule, IProcessorModule {
    uint256 public constant BPS_DENOMINATOR = 10_000;

    struct Split {
        address recipient;
        uint16 bps;
    }

    mapping(bytes32 activationId => Split[] splits) private _splits;

    error InvalidSplitRecipient();
    error InvalidSplitBps(uint256 totalBps);
    error NativeTokenNotSupported();

    /// @notice Store split recipients and basis points for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Split[] memory decoded = abi.decode(configData, (Split[]));
        delete _splits[activationId];

        uint256 totalBps = 0;
        uint256 length = decoded.length;
        for (uint256 i; i < length;) {
            if (decoded[i].recipient == address(0)) {
                revert InvalidSplitRecipient();
            }
            totalBps += decoded[i].bps;
            _splits[activationId].push(decoded[i]);
            unchecked {
                ++i;
            }
        }
        if (totalBps != BPS_DENOMINATOR) {
            revert InvalidSplitBps(totalBps);
        }
    }

    /// @inheritdoc IProcessorModule
    function processMint(NamespaceTypes.MintContext calldata ctx, NamespaceTypes.Price calldata price, bytes calldata)
        external
        onlyController
    {
        _split(ctx.activationId, price);
    }

    /// @inheritdoc IProcessorModule
    function processRenew(NamespaceTypes.RenewContext calldata ctx, NamespaceTypes.Price calldata price, bytes calldata)
        external
        onlyController
    {
        _split(ctx.activationId, price);
    }

    /// @notice Return split count for an activation.
    function splitCount(bytes32 activationId) external view returns (uint256) {
        return _splits[activationId].length;
    }

    /// @notice Return a split recipient and bps by index.
    function splitAt(bytes32 activationId, uint256 index) external view returns (Split memory) {
        return _splits[activationId][index];
    }

    function _split(bytes32 activationId, NamespaceTypes.Price calldata price) private {
        if (price.token == address(0)) {
            revert NativeTokenNotSupported();
        }

        Split[] storage stored = _splits[activationId];
        uint256 remaining = price.amount;
        uint256 last = stored.length - 1;

        for (uint256 i; i < last;) {
            uint256 amount = (price.amount * stored[i].bps) / BPS_DENOMINATOR;
            remaining -= amount;
            SafeTransferLib.safeTransfer(price.token, stored[i].recipient, amount);
            unchecked {
                ++i;
            }
        }
        SafeTransferLib.safeTransfer(price.token, stored[last].recipient, remaining);
    }
}
