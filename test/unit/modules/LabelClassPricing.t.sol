// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {LabelClassPricing} from "src/modules/pricing/LabelClassPricing.sol";
import {OnlyEmojiPricing} from "src/modules/pricing/OnlyEmojiPricing.sol";
import {OnlyLetterPricing} from "src/modules/pricing/OnlyLetterPricing.sol";
import {OnlyNumberPricing} from "src/modules/pricing/OnlyNumberPricing.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract LabelClassPricingTest is NamespaceSetUp {
    OnlyEmojiPricing internal emojiPricing;
    OnlyLetterPricing internal letterPricing;
    OnlyNumberPricing internal numberPricing;

    function setUp() public override {
        super.setUp();
        emojiPricing = new OnlyEmojiPricing(address(controller));
        letterPricing = new OnlyLetterPricing(address(controller));
        numberPricing = new OnlyNumberPricing(address(controller));
    }

    function test_onlyNumberPricing_addsPriceForNumberOnlyLabel() public {
        bytes32 activationId = keccak256("activation");
        _configure(numberPricing, activationId, 100, 50);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.label = "12345";

        NamespaceTypes.Price memory quoted =
            numberPricing.quoteMint(ctx, NamespaceTypes.Price({token: address(token), amount: 25}), "");

        assertEq(quoted.amount, 125);
    }

    function test_onlyNumberPricing_skipsMixedLabel() public {
        bytes32 activationId = keccak256("activation");
        _configure(numberPricing, activationId, 100, 50);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.label = "123a";

        NamespaceTypes.Price memory quoted =
            numberPricing.quoteMint(ctx, NamespaceTypes.Price({token: address(token), amount: 25}), "");

        assertEq(quoted.amount, 25);
    }

    function test_onlyLetterPricing_addsPriceForLetterOnlyLabel() public {
        bytes32 activationId = keccak256("activation");
        _configure(letterPricing, activationId, 100, 50);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.label = "Alice";

        NamespaceTypes.Price memory quoted =
            letterPricing.quoteMint(ctx, NamespaceTypes.Price({token: address(token), amount: 25}), "");

        assertEq(quoted.amount, 125);
    }

    function test_onlyEmojiPricing_addsPriceForEmojiOnlyLabel() public {
        bytes32 activationId = keccak256("activation");
        _configure(emojiPricing, activationId, 100, 50);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.label = unicode"😀🔥";

        NamespaceTypes.Price memory quoted =
            emojiPricing.quoteMint(ctx, NamespaceTypes.Price({token: address(token), amount: 25}), "");

        assertEq(quoted.amount, 125);
    }

    function _configure(LabelClassPricing pricing, bytes32 activationId, uint128 mintAmount, uint128 renewAmount)
        private
    {
        vm.prank(address(controller));
        pricing.configure(
            activationId,
            abi.encode(
                LabelClassPricing.Params({token: address(token), mintAmount: mintAmount, renewAmount: renewAmount})
            )
        );
    }
}
