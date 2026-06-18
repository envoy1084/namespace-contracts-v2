// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {MerkleWhitelistPolicy} from "src/modules/policies/MerkleWhitelistPolicy.sol";
import {CompositeMintPolicy} from "src/modules/policies/CompositeMintPolicy.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract CompositeMintPolicyTest is NamespaceSetUp {
    CompositeMintPolicy internal policy;
    bytes32 internal activationId;

    function setUp() public override {
        super.setUp();
        policy = CompositeMintPolicy(_deployModule(address(new CompositeMintPolicy())));
        activationId = keccak256("activation");
    }

    function test_checkMint_allowsFullCompositePolicy() public {
        bytes32 labelHash = keccak256("pay");
        uint64 expiry = uint64(block.timestamp + 30 days);
        bytes32 reservationLeaf = policy.leaf(labelHash, accounts.buyer.addr, expiry);
        bytes32 whitelistLeaf = _accountLabelLeaf(accounts.buyer.addr, labelHash);

        _configure(reservationLeaf, whitelistLeaf);

        NamespaceTypes.MintContext memory ctx = _mintCtx("pay");
        bytes32[] memory emptyProof = new bytes32[](0);
        bytes memory runtimeData = abi.encode(
            CompositeMintPolicy.ReservationProofData({account: accounts.buyer.addr, expiry: expiry, proof: emptyProof}),
            emptyProof
        );

        policy.checkMint(ctx, runtimeData);
    }

    function test_checkMint_revertsForInvalidWhitelistProof() public {
        bytes32 labelHash = keccak256("pay");
        uint64 expiry = uint64(block.timestamp + 30 days);
        bytes32 reservationLeaf = policy.leaf(labelHash, accounts.buyer.addr, expiry);
        bytes32 wrongWhitelistRoot = keccak256("wrong");

        _configure(reservationLeaf, wrongWhitelistRoot);

        NamespaceTypes.MintContext memory ctx = _mintCtx("pay");
        bytes32[] memory emptyProof = new bytes32[](0);
        bytes memory runtimeData = abi.encode(
            CompositeMintPolicy.ReservationProofData({account: accounts.buyer.addr, expiry: expiry, proof: emptyProof}),
            emptyProof
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                CompositeMintPolicy.CompositeInvalidWhitelistProof.selector,
                activationId,
                accounts.buyer.addr,
                labelHash,
                wrongWhitelistRoot
            )
        );
        policy.checkMint(ctx, runtimeData);
    }

    function _configure(bytes32 reservationRoot, bytes32 whitelistRoot) private {
        vm.prank(address(controller));
        policy.configure(
            activationId,
            abi.encode(
                CompositeMintPolicy.Params({
                    startTime: 0,
                    endTime: 0,
                    minLength: 1,
                    maxLength: 32,
                    gateToken: token,
                    minBalance: 100 ether,
                    reservationRoot: reservationRoot,
                    whitelistMintRoot: whitelistRoot,
                    whitelistRenewRoot: bytes32(0),
                    whitelistLeafMode: MerkleWhitelistPolicy.LeafMode.ACCOUNT_LABEL
                })
            )
        );
    }

    function _mintCtx(string memory label) private view returns (NamespaceTypes.MintContext memory ctx) {
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;
        ctx.payer = accounts.buyer.addr;
        ctx.label = label;
        ctx.labelHash = keccak256(bytes(label));
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
}
