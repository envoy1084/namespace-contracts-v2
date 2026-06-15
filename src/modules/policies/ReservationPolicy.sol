// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPolicyModule} from "src/interfaces/IPolicyModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title ReservationPolicy
/// @notice Blocks configured labels unless the reserved account is minting them.
/// @dev Reservations are activation-scoped sale rules. They do not reserve labels inside the
///      ENSv2 registry; they only gate whether the Namespace controller may call `register()`.
contract ReservationPolicy is NamespaceModule, IPolicyModule {
    /// @notice A single label reservation.
    /// @param labelHash Keccak hash of the direct child label.
    /// @param account Account allowed to mint the label. Use address(0) to block everyone until expiry.
    /// @param expiry Timestamp after which the reservation no longer applies. Use 0 for no expiry.
    struct ReservationInput {
        bytes32 labelHash;
        address account;
        uint64 expiry;
    }

    /// @notice Activation configuration.
    /// @param reservations Initial reservations to store for the activation.
    struct Params {
        ReservationInput[] reservations;
    }

    /// @notice Stored reservation data.
    /// @param account Account allowed to mint the label.
    /// @param expiry Timestamp after which the reservation no longer applies. Zero means no expiry.
    struct Reservation {
        address account;
        uint64 expiry;
    }

    mapping(bytes32 activationId => mapping(bytes32 labelHash => Reservation reservation)) public reservations;

    error EmptyReservationLabel(bytes32 activationId);
    error ReservedLabel(bytes32 activationId, string label, address reservedFor, uint64 expiry, address buyer);

    constructor(address controller_) NamespaceModule(controller_) {}

    /// @notice Store initial reservations for an activation.
    /// @dev Reconfiguring an activation replaces only the labels included in `configData`.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        uint256 length = decoded.reservations.length;
        for (uint256 i; i < length;) {
            ReservationInput memory input = decoded.reservations[i];
            if (input.labelHash == bytes32(0)) {
                revert EmptyReservationLabel(activationId);
            }
            reservations[activationId][input.labelHash] = Reservation({account: input.account, expiry: input.expiry});
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IPolicyModule
    function checkMint(NamespaceTypes.MintContext calldata ctx, bytes calldata) external view {
        Reservation memory reservation = reservations[ctx.activationId][ctx.labelHash];
        if (reservation.account == address(0) && reservation.expiry == 0) {
            return;
        }
        // Reservation expiry is intentionally timestamp-based sale policy state.
        // forge-lint: disable-next-line(block-timestamp)
        if (reservation.expiry != 0 && block.timestamp >= reservation.expiry) {
            return;
        }
        if (reservation.account != ctx.buyer) {
            revert ReservedLabel(ctx.activationId, ctx.label, reservation.account, reservation.expiry, ctx.buyer);
        }
    }

    /// @inheritdoc IPolicyModule
    function checkRenew(NamespaceTypes.RenewContext calldata, bytes calldata) external pure {}
}
