// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ReservationRule} from "src/modules/rules/ReservationRule.sol";
import {WhitelistRule} from "src/modules/rules/WhitelistRule.sol";
import {NamespaceBenchmarkModules} from "test/benchmarks/common/NamespaceBenchmarkModules.sol";

/// @notice Merkle claim, proof, and resolver-write helpers for benchmark scenarios.
abstract contract NamespaceBenchmarkClaims is NamespaceBenchmarkModules {
    function _reservationClaim(string memory label, uint256 setSize)
        internal
        view
        returns (ReservationRule.Claim memory claim)
    {
        claim = ReservationRule.Claim({
            labelHash: keccak256(bytes(label)),
            account: accounts.buyer.addr,
            startTime: 0,
            endTime: _reservationExpiry(),
            mintable: true,
            token: address(token),
            mintPrice: 1000 ether,
            renewPrice: 100 ether,
            priceOp: NamespaceTypes.PriceOp.OVERRIDE,
            proof: new bytes32[](0)
        });
        claim.proof = _proofFor(reservationRule.leaf(claim), setSize);
    }

    function _whitelistClaim(string memory label, uint256 setSize)
        internal
        view
        returns (WhitelistRule.Claim memory claim)
    {
        claim = WhitelistRule.Claim({
            labelHash: keccak256(bytes(label)),
            account: accounts.buyer.addr,
            startTime: 0,
            endTime: _reservationExpiry(),
            mintable: true,
            token: address(0),
            mintPrice: 0,
            renewPrice: 0,
            discountBps: 0,
            priceOp: NamespaceTypes.PriceOp.NONE,
            proof: new bytes32[](0)
        });
        claim.proof = _proofFor(whitelistRule.leaf(claim), setSize);
    }

    function _rootFor(bytes32 leaf, uint256 setSize) internal pure returns (bytes32 root) {
        root = leaf;
        bytes32[] memory proof = _proofFor(leaf, setSize);
        for (uint256 i; i < proof.length;) {
            root = _hashPair(root, proof[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _proofFor(bytes32 leaf, uint256 setSize) internal pure returns (bytes32[] memory proof) {
        uint256 depth = _ceilLog2(setSize);
        proof = new bytes32[](depth);
        for (uint256 i; i < depth;) {
            proof[i] = keccak256(abi.encodePacked("sibling", leaf, i, setSize));
            unchecked {
                ++i;
            }
        }
    }

    function _ceilLog2(uint256 value) internal pure returns (uint256 result) {
        if (value <= 1) return 0;
        uint256 n = value - 1;
        while (n != 0) {
            n >>= 1;
            ++result;
        }
    }

    function _reservationExpiry() internal view returns (uint64) {
        return uint64(block.timestamp + 30 days);
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32 result) {
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

    function _packedResolverOverrides(uint256 count) internal view returns (bytes memory packed) {
        packed = new bytes(count * 20);
        for (uint256 i; i < count;) {
            address override_ = i == 0 ? address(0) : _resolverOverride(i);
            uint256 offset = 32 + i * 20;
            assembly ("memory-safe") {
                let word := mload(add(packed, offset))
                mstore(add(packed, offset), or(shl(96, override_), and(word, 0xffffffffffffffffffffffff)))
            }
            unchecked {
                ++i;
            }
        }
    }

    function _resolverOverride(uint256 index) internal view returns (address) {
        if (index == 1) return accounts.alice.addr;
        if (index == 2) return accounts.treasury.addr;
        if (index == 3) return accounts.owner.addr;
        return address(controller);
    }
}
