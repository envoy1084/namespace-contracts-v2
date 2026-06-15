// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ReservationPolicy} from "src/modules/policies/ReservationPolicy.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract ReservationPolicyTest is NamespaceSetUp {
    ReservationPolicy internal reservationPolicy;

    function setUp() public override {
        super.setUp();
        reservationPolicy = new ReservationPolicy(address(controller));
    }

    function test_checkMint_revertsWhenReservedForDifferentBuyer() public {
        bytes32 activationId = keccak256("activation");
        bytes32 labelHash = keccak256(bytes("vip"));
        ReservationPolicy.ReservationInput[] memory reservations = new ReservationPolicy.ReservationInput[](1);
        reservations[0] = ReservationPolicy.ReservationInput({
            labelHash: labelHash, account: accounts.alice.addr, expiry: uint64(block.timestamp + 1 days)
        });

        vm.prank(address(controller));
        reservationPolicy.configure(activationId, abi.encode(ReservationPolicy.Params({reservations: reservations})));

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;
        ctx.label = "vip";
        ctx.labelHash = labelHash;

        vm.expectRevert(
            abi.encodeWithSelector(
                ReservationPolicy.ReservedLabel.selector,
                activationId,
                "vip",
                accounts.alice.addr,
                uint64(block.timestamp + 1 days),
                accounts.buyer.addr
            )
        );
        reservationPolicy.checkMint(ctx, "");
    }

    function test_checkMint_allowsReservedBuyer() public {
        bytes32 activationId = keccak256("activation");
        bytes32 labelHash = keccak256(bytes("vip"));
        ReservationPolicy.ReservationInput[] memory reservations = new ReservationPolicy.ReservationInput[](1);
        reservations[0] = ReservationPolicy.ReservationInput({
            labelHash: labelHash, account: accounts.buyer.addr, expiry: uint64(block.timestamp + 1 days)
        });

        vm.prank(address(controller));
        reservationPolicy.configure(activationId, abi.encode(ReservationPolicy.Params({reservations: reservations})));

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;
        ctx.label = "vip";
        ctx.labelHash = labelHash;

        reservationPolicy.checkMint(ctx, "");
    }

    function test_checkMint_allowsPublicMintAfterReservationExpiry() public {
        bytes32 activationId = keccak256("activation");
        bytes32 labelHash = keccak256(bytes("vip"));
        ReservationPolicy.ReservationInput[] memory reservations = new ReservationPolicy.ReservationInput[](1);
        reservations[0] = ReservationPolicy.ReservationInput({
            labelHash: labelHash, account: accounts.alice.addr, expiry: uint64(block.timestamp + 1 days)
        });

        vm.prank(address(controller));
        reservationPolicy.configure(activationId, abi.encode(ReservationPolicy.Params({reservations: reservations})));

        vm.warp(block.timestamp + 2 days);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;
        ctx.label = "vip";
        ctx.labelHash = labelHash;

        reservationPolicy.checkMint(ctx, "");
    }

    function test_checkMint_allowsPublicMintAtReservationExpiry() public {
        bytes32 activationId = keccak256("activation");
        bytes32 labelHash = keccak256(bytes("vip"));
        uint64 expiry = uint64(block.timestamp + 1 days);
        ReservationPolicy.ReservationInput[] memory reservations = new ReservationPolicy.ReservationInput[](1);
        reservations[0] =
            ReservationPolicy.ReservationInput({labelHash: labelHash, account: accounts.alice.addr, expiry: expiry});

        vm.prank(address(controller));
        reservationPolicy.configure(activationId, abi.encode(ReservationPolicy.Params({reservations: reservations})));

        vm.warp(expiry);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;
        ctx.label = "vip";
        ctx.labelHash = labelHash;

        reservationPolicy.checkMint(ctx, "");
    }
}
