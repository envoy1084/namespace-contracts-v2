// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20PaymentModule} from "src/modules/payment/ERC20PaymentModule.sol";
import {FixedPriceRule} from "src/modules/rules/FixedPriceRule.sol";
import {LabelLengthRule} from "src/modules/rules/LabelLengthRule.sol";
import {ReservationRule} from "src/modules/rules/ReservationRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

/// @notice Demonstration for the developer: base price 10, "abc" and "bcd" reserved at 20.
///         "abcd" is not reserved and should mint at base price 10 — but because
///         ReservationRule proves inclusion only (never non-inclusion), a set root forces
///         allowlist mode and the mint of "abcd" reverts instead of falling through to base.
contract ReservationUnreservedMintDemoTest is NamespaceSetUp {
    ReservationRule internal reservationRule;

    uint256 internal constant BASE_PRICE = 10 ether;
    uint256 internal constant RESERVED_PRICE = 20 ether;

    function setUp() public override {
        super.setUp();
        reservationRule = ReservationRule(_deployModule(address(new ReservationRule())));
        bytes32 ruleKind = controller.MODULE_KIND_RULE();
        vm.prank(accounts.owner.addr);
        controller.setModuleApproval(ruleKind, address(reservationRule), true);
    }

    function test_unreservedLabel_abcd_cannotBeMinted() public {
        // Reserve "abc" and "bcd" (price 20) in a two-leaf tree; base price is 10.
        bytes32 root = _hashPair(_leafFor("abc"), _leafFor("bcd"));
        vm.prank(accounts.alice.addr);
        bytes32 activationId = controller.activate(_aliceName(), _demoConfig(root));

        // "abcd" is not in the tree. No reservation claim can be produced for it, so the
        // mint reverts MissingReservationClaim rather than minting at base price 10.
        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), BASE_PRICE);
        vm.expectRevert(
            abi.encodeWithSelector(ReservationRule.MissingReservationClaim.selector, activationId, "abcd")
        );
        controller.mint(activationId, "abcd", 365 days, _runtime(""));
        vm.stopPrank();
    }

    function _demoConfig(bytes32 reservationRoot)
        private
        view
        returns (NamespaceTypes.ActivationConfig memory config)
    {
        NamespaceTypes.RuleConfig[] memory rules = new NamespaceTypes.RuleConfig[](3);
        rules[0] = NamespaceTypes.RuleConfig({
            module: address(labelLengthRule),
            phase: NamespaceTypes.RulePhase.ELIGIBILITY,
            configData: abi.encode(LabelLengthRule.Params({minLength: 3, maxLength: 12}))
        });
        rules[1] = NamespaceTypes.RuleConfig({
            module: address(fixedPriceRule),
            phase: NamespaceTypes.RulePhase.BASE_PRICE,
            configData: abi.encode(
                FixedPriceRule.Params({
                    token: address(token),
                    defaultMintAmount: uint128(BASE_PRICE),
                    defaultRenewAmount: uint128(BASE_PRICE),
                    lengthPrices: new FixedPriceRule.LengthPrice[](0)
                })
            )
        });
        rules[2] = NamespaceTypes.RuleConfig({
            module: address(reservationRule),
            phase: NamespaceTypes.RulePhase.OVERRIDE,
            configData: abi.encode(ReservationRule.Params({root: reservationRoot}))
        });

        config = NamespaceTypes.ActivationConfig({
            resolver: address(0xBEEF),
            buyerRoleBitmap: BUYER_ROLES,
            minDuration: 1,
            maxDuration: 365 days,
            rules: rules,
            paymentModule: NamespaceTypes.ModuleConfig({
                module: address(erc20Payment),
                configData: abi.encode(ERC20PaymentModule.Params({token: token, recipient: accounts.treasury.addr}))
            }),
            postHooks: new NamespaceTypes.ModuleConfig[](0)
        });
    }

    function _runtime(bytes memory reservationData)
        private
        pure
        returns (NamespaceTypes.RuntimeData memory runtimeData)
    {
        runtimeData.ruleData = new bytes[](3);
        runtimeData.ruleData[2] = reservationData;
        runtimeData.postHookData = new bytes[](0);
    }

    function _reservedClaim(string memory label) private view returns (ReservationRule.Claim memory claim) {
        claim.labelHash = keccak256(bytes(label));
        claim.account = address(0);
        claim.mintable = true;
        claim.token = address(token);
        claim.mintPrice = uint128(RESERVED_PRICE);
        claim.renewPrice = uint128(RESERVED_PRICE);
        claim.priceOp = NamespaceTypes.PriceOp.OVERRIDE;
        claim.proof = new bytes32[](0);
    }

    function _leafFor(string memory label) private view returns (bytes32) {
        return reservationRule.leaf(_reservedClaim(label));
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
