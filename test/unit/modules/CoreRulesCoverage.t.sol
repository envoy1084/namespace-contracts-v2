// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {FixedPriceRule} from "src/modules/rules/FixedPriceRule.sol";
import {LabelLengthRule} from "src/modules/rules/LabelLengthRule.sol";
import {LengthPremiumRule} from "src/modules/rules/LengthPremiumRule.sol";
import {SaleWindowRule} from "src/modules/rules/SaleWindowRule.sol";
import {TokenBalanceRule} from "src/modules/rules/TokenBalanceRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract CoreRulesCoverageTest is NamespaceSetUp {
    TokenBalanceRule internal tokenBalanceRule;
    LengthPremiumRule internal lengthPremiumRule;

    function setUp() public override {
        super.setUp();
        tokenBalanceRule = TokenBalanceRule(_deployModule(address(new TokenBalanceRule())));
        lengthPremiumRule = LengthPremiumRule(_deployModule(address(new LengthPremiumRule())));
    }

    function test_saleWindow_configureRevertsForInvalidWindow() public {
        bytes32 activationId = keccak256("activation");

        vm.expectRevert(abi.encodeWithSelector(SaleWindowRule.InvalidSaleWindow.selector, uint64(20), uint64(10)));
        vm.prank(address(controller));
        saleWindowRule.configure(activationId, abi.encode(SaleWindowRule.Params({startTime: 20, endTime: 10})));
    }

    function test_saleWindow_evaluateMintRevertsBeforeStartAndAfterEnd() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        saleWindowRule.configure(
            activationId, abi.encode(SaleWindowRule.Params({startTime: uint64(block.timestamp + 10), endTime: 0}))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                SaleWindowRule.SaleNotStarted.selector, activationId, uint64(block.timestamp + 10), block.timestamp
            )
        );
        saleWindowRule.evaluateMint(_mintCtx(activationId, "sale"), "");

        vm.warp(100);
        vm.prank(address(controller));
        saleWindowRule.configure(
            activationId, abi.encode(SaleWindowRule.Params({startTime: 0, endTime: uint64(block.timestamp - 1)}))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                SaleWindowRule.SaleEnded.selector, activationId, uint64(block.timestamp - 1), block.timestamp
            )
        );
        saleWindowRule.evaluateMint(_mintCtx(activationId, "sale"), "");
    }

    function test_saleWindow_evaluateRenewPassesInsideWindow() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        saleWindowRule.configure(
            activationId,
            abi.encode(
                SaleWindowRule.Params({startTime: uint64(block.timestamp - 1), endTime: uint64(block.timestamp + 1)})
            )
        );

        NamespaceTypes.RuleOutput memory output = saleWindowRule.evaluateRenew(_renewCtx(activationId, "sale"), "");
        assertEq(uint256(output.decision), uint256(NamespaceTypes.Decision.PASS));
    }

    function test_labelLength_configureRevertsForInvalidBounds() public {
        bytes32 activationId = keccak256("activation");

        vm.expectRevert(abi.encodeWithSelector(LabelLengthRule.InvalidLengthBounds.selector, uint16(10), uint16(3)));
        vm.prank(address(controller));
        labelLengthRule.configure(activationId, abi.encode(LabelLengthRule.Params({minLength: 10, maxLength: 3})));
    }

    function test_labelLength_evaluateMintRevertsForTooShortAndTooLong() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        labelLengthRule.configure(activationId, abi.encode(LabelLengthRule.Params({minLength: 3, maxLength: 5})));

        vm.expectRevert(
            abi.encodeWithSelector(LabelLengthRule.LabelTooShort.selector, activationId, "ab", uint256(2), uint16(3))
        );
        labelLengthRule.evaluateMint(_mintCtx(activationId, "ab"), "");

        vm.expectRevert(
            abi.encodeWithSelector(LabelLengthRule.LabelTooLong.selector, activationId, "abcdef", uint256(6), uint16(5))
        );
        labelLengthRule.evaluateMint(_mintCtx(activationId, "abcdef"), "");
    }

    function test_labelLength_evaluateRenewPassesWithoutMaxLength() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        labelLengthRule.configure(activationId, abi.encode(LabelLengthRule.Params({minLength: 1, maxLength: 0})));

        NamespaceTypes.RuleOutput memory output =
            labelLengthRule.evaluateRenew(_renewCtx(activationId, "longlabel"), "");
        assertEq(uint256(output.decision), uint256(NamespaceTypes.Decision.PASS));
    }

    function test_fixedPrice_configureRevertsForDuplicateLength() public {
        bytes32 activationId = keccak256("activation");
        FixedPriceRule.LengthPrice[] memory prices = new FixedPriceRule.LengthPrice[](2);
        prices[0] = FixedPriceRule.LengthPrice({length: 3, mintAmount: 1 ether, renewAmount: 0.5 ether});
        prices[1] = FixedPriceRule.LengthPrice({length: 3, mintAmount: 2 ether, renewAmount: 1 ether});

        vm.expectRevert(abi.encodeWithSelector(FixedPriceRule.DuplicateLengthPrice.selector, activationId, uint16(3)));
        vm.prank(address(controller));
        fixedPriceRule.configure(activationId, abi.encode(_fixedPriceParams(prices)));
    }

    function test_fixedPrice_configureRevertsForTooManyLengthPrices() public {
        bytes32 activationId = keccak256("activation");
        FixedPriceRule.LengthPrice[] memory prices = new FixedPriceRule.LengthPrice[](256);
        uint16 labelLength = 1;
        uint128 amount;
        for (uint256 i; i < prices.length; ++i) {
            prices[i] = FixedPriceRule.LengthPrice({length: labelLength, mintAmount: amount, renewAmount: amount});
            unchecked {
                ++labelLength;
                ++amount;
            }
        }

        vm.expectRevert(abi.encodeWithSelector(FixedPriceRule.TooManyLengthPrices.selector, activationId, 256));
        vm.prank(address(controller));
        fixedPriceRule.configure(activationId, abi.encode(_fixedPriceParams(prices)));
    }

    function test_fixedPrice_evaluateRenewUsesExactLengthOverrideAndRejectsEmptyLabel() public {
        bytes32 activationId = keccak256("activation");
        FixedPriceRule.LengthPrice[] memory prices = new FixedPriceRule.LengthPrice[](1);
        prices[0] = FixedPriceRule.LengthPrice({length: 3, mintAmount: 3 ether, renewAmount: 1 ether});

        vm.prank(address(controller));
        fixedPriceRule.configure(activationId, abi.encode(_fixedPriceParams(prices)));

        NamespaceTypes.RuleOutput memory output = fixedPriceRule.evaluateRenew(_renewCtx(activationId, "abc"), "");
        assertEq(output.amount, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(FixedPriceRule.EmptyLabel.selector));
        fixedPriceRule.evaluateMint(_mintCtx(activationId, ""), "");
    }

    function test_tokenBalance_configureRevertsForInvalidParams() public {
        bytes32 activationId = keccak256("activation");

        vm.expectRevert(abi.encodeWithSelector(TokenBalanceRule.InvalidTokenBalanceRule.selector, activationId));
        vm.prank(address(controller));
        tokenBalanceRule.configure(
            activationId,
            abi.encode(
                TokenBalanceRule.Params({token: ERC20(address(0)), minBalance: 1, discountBps: 0, minHoldTime: 1})
            )
        );

        vm.expectRevert(abi.encodeWithSelector(TokenBalanceRule.InvalidDiscountBps.selector, uint16(10_001)));
        vm.prank(address(controller));
        tokenBalanceRule.configure(
            activationId,
            abi.encode(TokenBalanceRule.Params({token: token, minBalance: 1, discountBps: 10_001, minHoldTime: 1}))
        );

        vm.expectRevert(abi.encodeWithSelector(TokenBalanceRule.InvalidTokenBalanceHoldTime.selector, activationId));
        vm.prank(address(controller));
        tokenBalanceRule.configure(
            activationId,
            abi.encode(TokenBalanceRule.Params({token: token, minBalance: 1, discountBps: 0, minHoldTime: 0}))
        );
    }

    function test_tokenBalance_evaluateRenewRevertsWhenBalanceIsLowAndDiscountsWhenEligible() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        tokenBalanceRule.configure(
            activationId,
            abi.encode(
                TokenBalanceRule.Params({token: token, minBalance: 2_000_000 ether, discountBps: 500, minHoldTime: 1})
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenBalanceRule.InsufficientTokenBalance.selector,
                activationId,
                accounts.buyer.addr,
                address(token),
                token.balanceOf(accounts.buyer.addr),
                2_000_000 ether
            )
        );
        tokenBalanceRule.evaluateRenew(_renewCtx(activationId, "token"), "");

        vm.prank(address(controller));
        tokenBalanceRule.configure(
            activationId,
            abi.encode(TokenBalanceRule.Params({token: token, minBalance: 1 ether, discountBps: 500, minHoldTime: 1}))
        );
        vm.prank(accounts.buyer.addr);
        tokenBalanceRule.recordBalance(activationId);
        vm.warp(block.timestamp + 1);

        NamespaceTypes.RuleOutput memory output = tokenBalanceRule.evaluateRenew(_renewCtx(activationId, "token"), "");
        assertEq(uint256(output.priceOp), uint256(NamespaceTypes.PriceOp.DISCOUNT_BPS));
        assertEq(output.bps, 500);
    }

    function test_tokenBalance_revertsWhenHoldTimeNotMet() public {
        bytes32 activationId = keccak256("activation");
        address temporaryHolder = makeAddr("temporaryHolder");
        vm.prank(address(controller));
        tokenBalanceRule.configure(
            activationId,
            abi.encode(TokenBalanceRule.Params({token: token, minBalance: 100 ether, discountBps: 500, minHoldTime: 1}))
        );

        vm.prank(accounts.buyer.addr);
        assertTrue(token.transfer(temporaryHolder, 100 ether));

        NamespaceTypes.MintContext memory ctx = _mintCtx(activationId, "token");
        ctx.buyer = temporaryHolder;
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenBalanceRule.TokenBalanceHoldTimeNotMet.selector,
                activationId,
                temporaryHolder,
                uint64(0),
                uint64(1),
                block.timestamp
            )
        );
        tokenBalanceRule.evaluateMint(ctx, "");
    }

    function test_lengthPremium_configureRevertsForEmptyAndTooLongTables() public {
        bytes32 activationId = keccak256("activation");
        uint128[] memory empty = new uint128[](0);
        uint128[] memory rates = new uint128[](1);
        rates[0] = 1;

        vm.expectRevert(abi.encodeWithSelector(LengthPremiumRule.EmptyPricingTable.selector));
        vm.prank(address(controller));
        lengthPremiumRule.configure(
            activationId,
            abi.encode(
                LengthPremiumRule.Params({
                    token: address(token), mintPricePerSecondByLength: empty, renewPricePerSecondByLength: rates
                })
            )
        );

        uint128[] memory tooLong = new uint128[](256);
        vm.expectRevert(abi.encodeWithSelector(LengthPremiumRule.PricingTableTooLong.selector, activationId, 256));
        vm.prank(address(controller));
        lengthPremiumRule.configure(
            activationId,
            abi.encode(
                LengthPremiumRule.Params({
                    token: address(token), mintPricePerSecondByLength: tooLong, renewPricePerSecondByLength: rates
                })
            )
        );
    }

    function test_lengthPremium_evaluateMintAndRenewUseFallbackBucketAndRejectEmptyLabel() public {
        bytes32 activationId = keccak256("activation");
        uint128[] memory mintRates = new uint128[](2);
        mintRates[0] = 1;
        mintRates[1] = 2;
        uint128[] memory renewRates = new uint128[](2);
        renewRates[0] = 3;
        renewRates[1] = 4;

        vm.prank(address(controller));
        lengthPremiumRule.configure(
            activationId,
            abi.encode(
                LengthPremiumRule.Params({
                    token: address(token),
                    mintPricePerSecondByLength: mintRates,
                    renewPricePerSecondByLength: renewRates
                })
            )
        );

        NamespaceTypes.RuleOutput memory mintOutput = lengthPremiumRule.evaluateMint(_mintCtx(activationId, "abc"), "");
        assertEq(mintOutput.amount, 2 * 365 days);

        NamespaceTypes.RuleOutput memory renewOutput =
            lengthPremiumRule.evaluateRenew(_renewCtx(activationId, "abc"), "");
        assertEq(renewOutput.amount, 4 * 30 days);

        vm.expectRevert(abi.encodeWithSelector(LengthPremiumRule.EmptyLabel.selector));
        lengthPremiumRule.evaluateMint(_mintCtx(activationId, ""), "");
    }

    function _fixedPriceParams(FixedPriceRule.LengthPrice[] memory prices)
        private
        view
        returns (FixedPriceRule.Params memory)
    {
        return FixedPriceRule.Params({
            token: address(token), defaultMintAmount: 10 ether, defaultRenewAmount: 5 ether, lengthPrices: prices
        });
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

    function _renewCtx(bytes32 activationId, string memory label)
        private
        view
        returns (NamespaceTypes.RenewContext memory ctx)
    {
        ctx.activationId = activationId;
        ctx.payer = accounts.buyer.addr;
        ctx.label = label;
        ctx.labelHash = keccak256(bytes(label));
        ctx.duration = 30 days;
    }
}
