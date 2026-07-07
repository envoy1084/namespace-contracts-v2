// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {IPaymentModule} from "src/interfaces/IPaymentModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title ERC20SplitPaymentModule
/// @notice Pulls ERC20 payment from the payer directly to split recipients.
/// @dev This combines payment collection and revenue splitting for gas-sensitive activations.
contract ERC20SplitPaymentModule is NamespaceModule, IPaymentModule {
    uint256 public constant BPS_DENOMINATOR = 10_000;

    struct Split {
        address recipient;
        uint16 bps;
    }

    struct Params {
        address token;
        Split[] splits;
    }

    struct StoredParams {
        address token;
        Split[] splits;
    }

    // slither-disable-next-line uninitialized-state
    mapping(bytes32 activationId => StoredParams params) private _params;

    error InvalidSplitRecipient();
    error InvalidSplitBps(uint256 totalBps);
    error PaymentTokenMismatch(address expected, address actual);
    error NativeValueNotAccepted(uint256 value);
    error PaymentAmountMismatch(address token, address recipient, uint256 expected, uint256 actual);

    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        StoredParams storage stored = _params[activationId];
        delete stored.splits;
        stored.token = decoded.token;

        uint256 totalBps = 0;
        uint256 length = decoded.splits.length;
        for (uint256 i; i < length;) {
            if (decoded.splits[i].recipient == address(0)) {
                revert InvalidSplitRecipient();
            }
            totalBps += decoded.splits[i].bps;
            stored.splits.push(decoded.splits[i]);
            unchecked {
                ++i;
            }
        }
        if (totalBps != BPS_DENOMINATOR) {
            revert InvalidSplitBps(totalBps);
        }
    }

    function collectMint(NamespaceTypes.MintContext calldata ctx, NamespaceTypes.Price calldata price, bytes calldata)
        external
        payable
        onlyController
    {
        _collect(ctx.activationId, ctx.payer, price);
    }

    function collectRenew(NamespaceTypes.RenewContext calldata ctx, NamespaceTypes.Price calldata price, bytes calldata)
        external
        payable
        onlyController
    {
        _collect(ctx.activationId, ctx.payer, price);
    }

    function splitCount(bytes32 activationId) external view returns (uint256) {
        return _params[activationId].splits.length;
    }

    function splitAt(bytes32 activationId, uint256 index) external view returns (Split memory) {
        return _params[activationId].splits[index];
    }

    function token(bytes32 activationId) external view returns (address) {
        return _params[activationId].token;
    }

    function _collect(bytes32 activationId, address payer, NamespaceTypes.Price calldata price) private {
        if (msg.value != 0) {
            revert NativeValueNotAccepted(msg.value);
        }

        StoredParams storage stored = _params[activationId];
        address token_ = stored.token;
        if (token_ != price.token) {
            revert PaymentTokenMismatch(token_, price.token);
        }

        Split[] storage splits = stored.splits;
        uint256 total = price.amount;
        uint256 remaining = total;
        uint256 last = splits.length - 1;
        for (uint256 i; i < last;) {
            Split storage split = splits[i];
            uint256 amount = (total * split.bps) / BPS_DENOMINATOR;
            remaining -= amount;
            _transferExact(token_, payer, split.recipient, amount);
            unchecked {
                ++i;
            }
        }
        _transferExact(token_, payer, splits[last].recipient, remaining);
    }

    function _transferExact(address token_, address payer, address recipient, uint256 amount) private {
        uint256 beforeBalance = ERC20(token_).balanceOf(recipient);
        SafeTransferLib.safeTransferFrom(token_, payer, recipient, amount);
        uint256 received = ERC20(token_).balanceOf(recipient) - beforeBalance;
        if (received != amount) {
            revert PaymentAmountMismatch(token_, recipient, amount, received);
        }
    }
}
