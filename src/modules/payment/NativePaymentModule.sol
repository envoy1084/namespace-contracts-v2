// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {IPaymentModule} from "src/interfaces/IPaymentModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title NativePaymentModule
/// @notice Collects native ETH payments for mints and renewals.
contract NativePaymentModule is NamespaceModule, IPaymentModule {
    struct Params {
        address recipient;
    }

    mapping(bytes32 activationId => Params params) public params;

    error InvalidPaymentRecipient();
    error PaymentTokenMismatch(address expected, address actual);
    error NativePaymentAmountMismatch(uint256 expected, uint256 actual);

    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (decoded.recipient == address(0)) {
            revert InvalidPaymentRecipient();
        }
        params[activationId] = decoded;
    }

    function collectMint(NamespaceTypes.MintContext calldata ctx, NamespaceTypes.Price calldata price, bytes calldata)
        external
        payable
        onlyController
    {
        _collect(ctx.activationId, price);
    }

    function collectRenew(NamespaceTypes.RenewContext calldata ctx, NamespaceTypes.Price calldata price, bytes calldata)
        external
        payable
        onlyController
    {
        _collect(ctx.activationId, price);
    }

    function _collect(bytes32 activationId, NamespaceTypes.Price calldata price) private {
        if (price.token != address(0)) {
            revert PaymentTokenMismatch(address(0), price.token);
        }
        if (msg.value != price.amount) {
            revert NativePaymentAmountMismatch(price.amount, msg.value);
        }
        if (price.amount != 0) {
            SafeTransferLib.safeTransferETH(params[activationId].recipient, price.amount);
        }
    }
}
