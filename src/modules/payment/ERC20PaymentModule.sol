// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {IPaymentModule} from "src/interfaces/IPaymentModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title ERC20PaymentModule
/// @notice Collects ERC20 payments for mints and renewals.
/// @dev Funds are transferred to the activation-scoped recipient. For split processing, configure
///      the recipient as the processor contract and call a split processor after collection.
contract ERC20PaymentModule is NamespaceModule, IPaymentModule {
    /// @notice ERC20 payment params for one activation.
    /// @param token ERC20 token accepted by this payment module.
    /// @param recipient Address receiving collected funds.
    struct Params {
        ERC20 token;
        address recipient;
    }

    mapping(bytes32 activationId => Params params) public params;

    error InvalidPaymentRecipient();
    error PaymentTokenMismatch(address expected, address actual);
    error NativeValueNotAccepted(uint256 value);

    /// @notice Store ERC20 payment parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (decoded.recipient == address(0)) {
            revert InvalidPaymentRecipient();
        }
        params[activationId] = decoded;
    }

    /// @inheritdoc IPaymentModule
    function collectMint(NamespaceTypes.MintContext calldata ctx, NamespaceTypes.Price calldata price, bytes calldata)
        external
        payable
        onlyController
    {
        _collect(ctx.activationId, ctx.payer, price);
    }

    /// @inheritdoc IPaymentModule
    function collectRenew(NamespaceTypes.RenewContext calldata ctx, NamespaceTypes.Price calldata price, bytes calldata)
        external
        payable
        onlyController
    {
        _collect(ctx.activationId, ctx.payer, price);
    }

    function _collect(bytes32 activationId, address payer, NamespaceTypes.Price calldata price) private {
        if (msg.value != 0) {
            revert NativeValueNotAccepted(msg.value);
        }

        Params memory stored = params[activationId];
        if (address(stored.token) != price.token) {
            revert PaymentTokenMismatch(address(stored.token), price.token);
        }
        if (price.amount != 0) {
            SafeTransferLib.safeTransferFrom(address(stored.token), payer, stored.recipient, price.amount);
        }
    }
}
