// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {MerkleWhitelistPolicy} from "src/modules/policies/MerkleWhitelistPolicy.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract MerkleWhitelistPolicyTest is NamespaceSetUp {
    MerkleWhitelistPolicy internal whitelistPolicy;

    function setUp() public override {
        super.setUp();
        whitelistPolicy = MerkleWhitelistPolicy(_deployModule(address(new MerkleWhitelistPolicy())));
    }

    function test_checkMint_allowsAccountLeafProof() public {
        bytes32 activationId = keccak256("activation");
        bytes32 buyerLeaf = _accountLeaf(accounts.buyer.addr);
        bytes32 aliceLeaf = _accountLeaf(accounts.alice.addr);
        bytes32 root = _hashPair(buyerLeaf, aliceLeaf);

        vm.prank(address(controller));
        whitelistPolicy.configure(
            activationId,
            abi.encode(
                MerkleWhitelistPolicy.Params({
                    mintRoot: root, renewRoot: bytes32(0), leafMode: MerkleWhitelistPolicy.LeafMode.ACCOUNT
                })
            )
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;
        ctx.labelHash = keccak256(bytes("pay"));

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = aliceLeaf;

        whitelistPolicy.checkMint(ctx, abi.encode(proof));
    }

    function test_checkMint_revertsForInvalidAccountProof() public {
        bytes32 activationId = keccak256("activation");
        bytes32 buyerLeaf = _accountLeaf(accounts.buyer.addr);
        bytes32 aliceLeaf = _accountLeaf(accounts.alice.addr);
        bytes32 root = _hashPair(buyerLeaf, aliceLeaf);

        vm.prank(address(controller));
        whitelistPolicy.configure(
            activationId,
            abi.encode(
                MerkleWhitelistPolicy.Params({
                    mintRoot: root, renewRoot: bytes32(0), leafMode: MerkleWhitelistPolicy.LeafMode.ACCOUNT
                })
            )
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.buyer = accounts.treasury.addr;
        ctx.labelHash = keccak256(bytes("pay"));

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = aliceLeaf;

        vm.expectRevert(
            abi.encodeWithSelector(
                MerkleWhitelistPolicy.InvalidWhitelistProof.selector,
                activationId,
                accounts.treasury.addr,
                keccak256(bytes("pay")),
                root
            )
        );
        whitelistPolicy.checkMint(ctx, abi.encode(proof));
    }

    function test_checkMint_revertsWhenAccountLabelDoesNotMatch() public {
        bytes32 activationId = keccak256("activation");
        bytes32 vipLabel = keccak256(bytes("vip"));
        bytes32 payLabel = keccak256(bytes("pay"));
        bytes32 buyerVipLeaf = _accountLabelLeaf(accounts.buyer.addr, vipLabel);
        bytes32 aliceVipLeaf = _accountLabelLeaf(accounts.alice.addr, vipLabel);
        bytes32 root = _hashPair(buyerVipLeaf, aliceVipLeaf);

        vm.prank(address(controller));
        whitelistPolicy.configure(
            activationId,
            abi.encode(
                MerkleWhitelistPolicy.Params({
                    mintRoot: root, renewRoot: bytes32(0), leafMode: MerkleWhitelistPolicy.LeafMode.ACCOUNT_LABEL
                })
            )
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;
        ctx.labelHash = payLabel;

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = aliceVipLeaf;

        vm.expectRevert(
            abi.encodeWithSelector(
                MerkleWhitelistPolicy.InvalidWhitelistProof.selector, activationId, accounts.buyer.addr, payLabel, root
            )
        );
        whitelistPolicy.checkMint(ctx, abi.encode(proof));
    }

    function test_checkRenew_usesRenewRoot() public {
        bytes32 activationId = keccak256("activation");
        bytes32 labelHash = keccak256(bytes("pay"));
        bytes32 buyerLeaf = _accountLabelLeaf(accounts.buyer.addr, labelHash);
        bytes32 aliceLeaf = _accountLabelLeaf(accounts.alice.addr, labelHash);
        bytes32 root = _hashPair(buyerLeaf, aliceLeaf);

        vm.prank(address(controller));
        whitelistPolicy.configure(
            activationId,
            abi.encode(
                MerkleWhitelistPolicy.Params({
                    mintRoot: bytes32(0), renewRoot: root, leafMode: MerkleWhitelistPolicy.LeafMode.ACCOUNT_LABEL
                })
            )
        );

        NamespaceTypes.RenewContext memory ctx;
        ctx.activationId = activationId;
        ctx.payer = accounts.buyer.addr;
        ctx.labelHash = labelHash;

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = aliceLeaf;

        whitelistPolicy.checkRenew(ctx, abi.encode(proof));
    }

    function test_checkMint_allowsWithoutProofWhenRootDisabled() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        whitelistPolicy.configure(
            activationId,
            abi.encode(
                MerkleWhitelistPolicy.Params({
                    mintRoot: bytes32(0), renewRoot: bytes32(0), leafMode: MerkleWhitelistPolicy.LeafMode.ACCOUNT_LABEL
                })
            )
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;
        ctx.labelHash = keccak256(bytes("pay"));

        whitelistPolicy.checkMint(ctx, "");
    }

    function _accountLeaf(address account) private pure returns (bytes32 result) {
        bytes32 inner;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, account)
            inner := keccak256(ptr, 0x20)
            mstore(ptr, inner)
            result := keccak256(ptr, 0x20)
        }
    }

    function _accountLabelLeaf(address account, bytes32 labelHash) private pure returns (bytes32 result) {
        bytes32 inner;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, account)
            mstore(add(ptr, 0x20), labelHash)
            inner := keccak256(ptr, 0x40)
            mstore(ptr, inner)
            result := keccak256(ptr, 0x20)
        }
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            let first := b
            let second := a
            if lt(a, b) {
                first := a
                second := b
            }
            mstore(ptr, first)
            mstore(add(ptr, 0x20), second)
            result := keccak256(ptr, 0x40)
        }
    }
}
