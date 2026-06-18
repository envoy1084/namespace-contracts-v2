// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {LabelClassRule} from "src/modules/rules/LabelClassRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract LabelClassRuleTest is NamespaceSetUp {
    LabelClassRule internal rule;

    function setUp() public override {
        super.setUp();
        rule = LabelClassRule(_deployModule(address(new LabelClassRule())));
    }

    function test_evaluateMint_pricesNumberLabel() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, LabelClassRule.LabelClass.NUMBER, false, 10 ether, 5 ether);

        NamespaceTypes.RuleOutput memory output = rule.evaluateMint(_mintCtx(activationId, "12345"), "");

        assertEq(uint256(output.decision), uint256(NamespaceTypes.Decision.PASS));
        assertEq(uint256(output.priceOp), uint256(NamespaceTypes.PriceOp.ADD));
        assertEq(output.token, address(token));
        assertEq(output.amount, 10 ether);
    }

    function test_evaluateMint_skipsNonMatchingLabelWhenNotRequired() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, LabelClassRule.LabelClass.NUMBER, false, 10 ether, 5 ether);

        NamespaceTypes.RuleOutput memory output = rule.evaluateMint(_mintCtx(activationId, "abc123"), "");

        assertEq(uint256(output.decision), uint256(NamespaceTypes.Decision.PASS));
        assertEq(uint256(output.priceOp), uint256(NamespaceTypes.PriceOp.NONE));
    }

    function test_evaluateMint_revertsWhenClassRequired() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, LabelClassRule.LabelClass.LETTER, true, 10 ether, 5 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                LabelClassRule.LabelClassMismatch.selector, activationId, "abc123", LabelClassRule.LabelClass.LETTER
            )
        );
        rule.evaluateMint(_mintCtx(activationId, "abc123"), "");
    }

    function test_evaluateMint_pricesEmojiLabel() public {
        bytes32 activationId = keccak256("activation");
        _configure(activationId, LabelClassRule.LabelClass.EMOJI, true, 10 ether, 5 ether);

        NamespaceTypes.RuleOutput memory output = rule.evaluateMint(_mintCtx(activationId, unicode"🔥"), "");

        assertEq(output.amount, 10 ether);
    }

    function _configure(
        bytes32 activationId,
        LabelClassRule.LabelClass class,
        bool requireMatch,
        uint128 mintAmount,
        uint128 renewAmount
    ) private {
        vm.prank(address(controller));
        rule.configure(
            activationId,
            abi.encode(
                LabelClassRule.Params({
                    token: address(token),
                    labelClass: class,
                    requireMatch: requireMatch,
                    mintAmount: mintAmount,
                    renewAmount: renewAmount,
                    priceOp: NamespaceTypes.PriceOp.ADD
                })
            )
        );
    }

    function _mintCtx(bytes32 activationId, string memory label)
        private
        view
        returns (NamespaceTypes.MintContext memory ctx)
    {
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;
        ctx.payer = accounts.buyer.addr;
        ctx.label = label;
        ctx.labelHash = keccak256(bytes(label));
        ctx.duration = 365 days;
    }
}
