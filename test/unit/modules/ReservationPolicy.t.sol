// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ReservationPolicy} from "src/modules/policies/ReservationPolicy.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract ReservationPolicyTest is NamespaceSetUp {
    ReservationPolicy internal reservationPolicy;

    function setUp() public override {
        super.setUp();
        reservationPolicy = ReservationPolicy(_deployModule(address(new ReservationPolicy())));
    }

    function test_checkMint_revertsWhenReservedForDifferentBuyer() public {
        bytes32 activationId = keccak256("activation");
        bytes32 labelHash = keccak256(bytes("vip"));
        uint64 expiry = uint64(block.timestamp + 1 days);
        bytes32 reservedLeaf = reservationPolicy.leaf(labelHash, accounts.alice.addr, expiry);

        vm.prank(address(controller));
        reservationPolicy.configure(activationId, abi.encode(ReservationPolicy.Params({reservationRoot: reservedLeaf})));

        NamespaceTypes.MintContext memory ctx = _mintContext(activationId, "vip", labelHash, accounts.buyer.addr);

        vm.expectRevert(
            abi.encodeWithSelector(
                ReservationPolicy.ReservedLabel.selector,
                activationId,
                "vip",
                accounts.alice.addr,
                expiry,
                accounts.buyer.addr
            )
        );
        reservationPolicy.checkMint(ctx, _proofData(accounts.alice.addr, expiry, new bytes32[](0)));
    }

    function test_checkMint_allowsReservedBuyer() public {
        bytes32 activationId = keccak256("activation");
        bytes32 labelHash = keccak256(bytes("vip"));
        uint64 expiry = uint64(block.timestamp + 1 days);
        bytes32 reservedLeaf = reservationPolicy.leaf(labelHash, accounts.buyer.addr, expiry);

        vm.prank(address(controller));
        reservationPolicy.configure(activationId, abi.encode(ReservationPolicy.Params({reservationRoot: reservedLeaf})));

        NamespaceTypes.MintContext memory ctx = _mintContext(activationId, "vip", labelHash, accounts.buyer.addr);

        reservationPolicy.checkMint(ctx, _proofData(accounts.buyer.addr, expiry, new bytes32[](0)));
    }

    function test_checkMint_allowsAnyBuyerForPublicLeaf() public {
        bytes32 activationId = keccak256("activation");
        bytes32 labelHash = keccak256(bytes("vip"));
        bytes32 publicLeaf = reservationPolicy.leaf(labelHash, address(0), 0);

        vm.prank(address(controller));
        reservationPolicy.configure(activationId, abi.encode(ReservationPolicy.Params({reservationRoot: publicLeaf})));

        NamespaceTypes.MintContext memory ctx = _mintContext(activationId, "vip", labelHash, accounts.buyer.addr);

        reservationPolicy.checkMint(ctx, _proofData(address(0), 0, new bytes32[](0)));
    }

    function test_checkMint_revertsWithoutProofWhenRootEnabled() public {
        bytes32 activationId = keccak256("activation");
        bytes32 labelHash = keccak256(bytes("vip"));
        bytes32 publicLeaf = reservationPolicy.leaf(labelHash, address(0), 0);

        vm.prank(address(controller));
        reservationPolicy.configure(activationId, abi.encode(ReservationPolicy.Params({reservationRoot: publicLeaf})));

        NamespaceTypes.MintContext memory ctx = _mintContext(activationId, "vip", labelHash, accounts.buyer.addr);

        vm.expectRevert(abi.encodeWithSelector(ReservationPolicy.MissingReservationProof.selector, activationId, "vip"));
        reservationPolicy.checkMint(ctx, "");
    }

    function test_checkMint_revertsForMalformedProofData() public {
        bytes32 activationId = keccak256("activation");
        bytes32 labelHash = keccak256(bytes("vip"));
        bytes32 publicLeaf = reservationPolicy.leaf(labelHash, address(0), 0);

        vm.prank(address(controller));
        reservationPolicy.configure(activationId, abi.encode(ReservationPolicy.Params({reservationRoot: publicLeaf})));

        NamespaceTypes.MintContext memory ctx = _mintContext(activationId, "vip", labelHash, accounts.buyer.addr);

        vm.expectRevert(
            abi.encodeWithSelector(
                ReservationPolicy.InvalidReservationProof.selector, activationId, labelHash, address(0), 0
            )
        );
        reservationPolicy.checkMint(ctx, hex"1234");
    }

    function test_checkMint_allowsPublicMintAfterReservationExpiry() public {
        bytes32 activationId = keccak256("activation");
        bytes32 labelHash = keccak256(bytes("vip"));
        uint64 expiry = uint64(block.timestamp + 1 days);
        bytes32 reservedLeaf = reservationPolicy.leaf(labelHash, accounts.alice.addr, expiry);

        vm.prank(address(controller));
        reservationPolicy.configure(activationId, abi.encode(ReservationPolicy.Params({reservationRoot: reservedLeaf})));

        vm.warp(block.timestamp + 2 days);

        NamespaceTypes.MintContext memory ctx = _mintContext(activationId, "vip", labelHash, accounts.buyer.addr);

        reservationPolicy.checkMint(ctx, _proofData(accounts.alice.addr, expiry, new bytes32[](0)));
    }

    function _mintContext(bytes32 activationId, string memory label, bytes32 labelHash, address buyer)
        private
        pure
        returns (NamespaceTypes.MintContext memory ctx)
    {
        ctx.activationId = activationId;
        ctx.buyer = buyer;
        ctx.label = label;
        ctx.labelHash = labelHash;
    }

    function _proofData(address account, uint64 expiry, bytes32[] memory proof) private pure returns (bytes memory) {
        return abi.encode(ReservationPolicy.ProofData({account: account, expiry: expiry, proof: proof}));
    }
}
