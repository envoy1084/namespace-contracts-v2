// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ReservationRule} from "src/modules/rules/ReservationRule.sol";
import {WhitelistRule} from "src/modules/rules/WhitelistRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract ClaimRulesCoverageTest is NamespaceSetUp {
    ReservationRule internal reservationRule;
    WhitelistRule internal whitelistRule;

    function setUp() public override {
        super.setUp();
        reservationRule = ReservationRule(_deployModule(address(new ReservationRule())));
        whitelistRule = WhitelistRule(_deployModule(address(new WhitelistRule())));
    }

    function test_whitelist_evaluateMintPassesWhenRootDisabled() public {
        bytes32 activationId = keccak256("activation");
        _configureWhitelist(activationId, bytes32(0), bytes32(0));

        NamespaceTypes.RuleOutput memory output = whitelistRule.evaluateMint(_mintCtx(activationId, "open"), "");

        assertEq(uint256(output.decision), uint256(NamespaceTypes.Decision.PASS));
        assertEq(uint256(output.priceOp), uint256(NamespaceTypes.PriceOp.NONE));
    }

    function test_whitelist_revertsForMissingAndInvalidClaim() public {
        bytes32 activationId = keccak256("activation");
        bytes32 root = keccak256("root");
        _configureWhitelist(activationId, root, bytes32(0));

        vm.expectRevert(abi.encodeWithSelector(WhitelistRule.MissingWhitelistClaim.selector, activationId, root));
        whitelistRule.evaluateMint(_mintCtx(activationId, "vip"), "");

        WhitelistRule.Claim memory claim = _whitelistClaim("vip");
        vm.expectRevert(
            abi.encodeWithSelector(
                WhitelistRule.InvalidWhitelistClaim.selector, activationId, claim.labelHash, claim.account
            )
        );
        whitelistRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));
    }

    function test_whitelist_revertsForClaimGuards() public {
        bytes32 activationId = keccak256("activation");
        WhitelistRule.Claim memory claim = _whitelistClaim("vip");

        claim.startTime = uint64(block.timestamp + 10);
        _configureWhitelistForClaim(activationId, claim, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                WhitelistRule.WhitelistNotStarted.selector, activationId, claim.startTime, block.timestamp
            )
        );
        whitelistRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));

        claim = _whitelistClaim("vip");
        claim.endTime = uint64(block.timestamp);
        _configureWhitelistForClaim(activationId, claim, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                WhitelistRule.WhitelistClaimExpired.selector, activationId, claim.endTime, block.timestamp
            )
        );
        whitelistRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));

        claim = _whitelistClaim("vip");
        claim.mintable = false;
        _configureWhitelistForClaim(activationId, claim, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                WhitelistRule.WhitelistClaimBlocked.selector, activationId, claim.labelHash, claim.account
            )
        );
        whitelistRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));

        claim = _whitelistClaim("vip");
        claim.account = accounts.owner.addr;
        _configureWhitelistForClaim(activationId, claim, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                WhitelistRule.WhitelistAccountMismatch.selector, activationId, accounts.owner.addr, accounts.buyer.addr
            )
        );
        whitelistRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));

        claim = _whitelistClaim("vip");
        _configureWhitelistForClaim(activationId, claim, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                WhitelistRule.WhitelistLabelMismatch.selector, activationId, claim.labelHash, keccak256(bytes("other"))
            )
        );
        whitelistRule.evaluateMint(_mintCtx(activationId, "other"), abi.encode(claim));
    }

    function test_whitelist_revertsForInvalidPricing() public {
        bytes32 activationId = keccak256("activation");
        WhitelistRule.Claim memory claim = _whitelistClaim("vip");
        claim.discountBps = 10_001;
        _configureWhitelistForClaim(activationId, claim, true);

        vm.expectRevert(abi.encodeWithSelector(WhitelistRule.InvalidWhitelistDiscount.selector, uint16(10_001)));
        whitelistRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));

        claim = _whitelistClaim("vip");
        claim.priceOp = NamespaceTypes.PriceOp.SET_BASE;
        _configureWhitelistForClaim(activationId, claim, true);

        vm.expectRevert(
            abi.encodeWithSelector(WhitelistRule.InvalidWhitelistPriceOp.selector, NamespaceTypes.PriceOp.SET_BASE)
        );
        whitelistRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));
    }

    function test_whitelist_evaluateMintAppliesDiscountBps() public {
        bytes32 activationId = keccak256("activation");
        WhitelistRule.Claim memory claim = _whitelistClaim("vip");
        claim.discountBps = 500;
        _configureWhitelistForClaim(activationId, claim, true);

        NamespaceTypes.RuleOutput memory output =
            whitelistRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));

        assertEq(uint256(output.priceOp), uint256(NamespaceTypes.PriceOp.DISCOUNT_BPS));
        assertEq(output.bps, 500);
    }

    function test_whitelist_evaluateRenewUsesRenewRootAndPrice() public {
        bytes32 activationId = keccak256("activation");
        WhitelistRule.Claim memory claim = _whitelistClaim("vip");
        claim.priceOp = NamespaceTypes.PriceOp.OVERRIDE;
        claim.token = address(token);
        claim.mintPrice = 10 ether;
        claim.renewPrice = 4 ether;
        _configureWhitelistForClaim(activationId, claim, false);

        NamespaceTypes.RuleOutput memory output =
            whitelistRule.evaluateRenew(_renewCtx(activationId, "vip"), abi.encode(claim));

        assertEq(uint256(output.priceOp), uint256(NamespaceTypes.PriceOp.OVERRIDE));
        assertEq(output.token, address(token));
        assertEq(output.amount, 4 ether);
    }

    function test_reservation_evaluateMintPassesWhenRootDisabled() public {
        bytes32 activationId = keccak256("activation");
        _configureReservation(activationId, bytes32(0));

        NamespaceTypes.RuleOutput memory output = reservationRule.evaluateMint(_mintCtx(activationId, "open"), "");

        assertEq(uint256(output.decision), uint256(NamespaceTypes.Decision.PASS));
        assertEq(uint256(output.priceOp), uint256(NamespaceTypes.PriceOp.NONE));
    }

    function test_reservation_revertsForMissingAndInvalidClaim() public {
        bytes32 activationId = keccak256("activation");
        bytes32 root = keccak256("root");
        _configureReservation(activationId, root);

        vm.expectRevert(abi.encodeWithSelector(ReservationRule.MissingReservationClaim.selector, activationId, "vip"));
        reservationRule.evaluateMint(_mintCtx(activationId, "vip"), "");

        ReservationRule.Claim memory claim = _reservationClaim("vip");
        vm.expectRevert(
            abi.encodeWithSelector(
                ReservationRule.InvalidReservationClaim.selector, activationId, claim.labelHash, claim.account
            )
        );
        reservationRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));
    }

    function test_reservation_revertsForClaimGuards() public {
        bytes32 activationId = keccak256("activation");
        ReservationRule.Claim memory claim = _reservationClaim("vip");

        claim.startTime = uint64(block.timestamp + 10);
        _configureReservationForClaim(activationId, claim);
        vm.expectRevert(
            abi.encodeWithSelector(
                ReservationRule.ReservationNotStarted.selector,
                activationId,
                claim.labelHash,
                claim.startTime,
                block.timestamp
            )
        );
        reservationRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));

        claim = _reservationClaim("vip");
        claim.mintable = false;
        _configureReservationForClaim(activationId, claim);
        vm.expectRevert(
            abi.encodeWithSelector(ReservationRule.ReservedLabelBlocked.selector, activationId, claim.labelHash)
        );
        reservationRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));

        claim = _reservationClaim("vip");
        claim.account = accounts.owner.addr;
        _configureReservationForClaim(activationId, claim);
        vm.expectRevert(
            abi.encodeWithSelector(
                ReservationRule.ReservedForDifferentAccount.selector,
                activationId,
                claim.labelHash,
                accounts.owner.addr,
                accounts.buyer.addr
            )
        );
        reservationRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));
    }

    function test_reservation_expiredClaimDoesNotApply() public {
        bytes32 activationId = keccak256("activation");
        ReservationRule.Claim memory claim = _reservationClaim("vip");
        claim.endTime = uint64(block.timestamp);
        claim.priceOp = NamespaceTypes.PriceOp.OVERRIDE;
        claim.mintPrice = 100 ether;
        _configureReservationForClaim(activationId, claim);

        NamespaceTypes.RuleOutput memory output =
            reservationRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));

        assertEq(uint256(output.priceOp), uint256(NamespaceTypes.PriceOp.NONE));
    }

    function test_reservation_revertsForInvalidPricingAndUsesRenewPrice() public {
        bytes32 activationId = keccak256("activation");
        ReservationRule.Claim memory claim = _reservationClaim("vip");
        claim.priceOp = NamespaceTypes.PriceOp.SET_BASE;
        _configureReservationForClaim(activationId, claim);

        vm.expectRevert(
            abi.encodeWithSelector(ReservationRule.InvalidReservationPriceOp.selector, NamespaceTypes.PriceOp.SET_BASE)
        );
        reservationRule.evaluateMint(_mintCtx(activationId, "vip"), abi.encode(claim));

        claim = _reservationClaim("vip");
        claim.priceOp = NamespaceTypes.PriceOp.OVERRIDE;
        claim.token = address(token);
        claim.mintPrice = 10 ether;
        claim.renewPrice = 3 ether;
        _configureReservationForClaim(activationId, claim);

        NamespaceTypes.RuleOutput memory output =
            reservationRule.evaluateRenew(_renewCtx(activationId, "vip"), abi.encode(claim));

        assertEq(uint256(output.priceOp), uint256(NamespaceTypes.PriceOp.OVERRIDE));
        assertEq(output.token, address(token));
        assertEq(output.amount, 3 ether);
    }

    function _configureWhitelistForClaim(bytes32 activationId, WhitelistRule.Claim memory claim, bool mint) private {
        bytes32 root = whitelistRule.leaf(claim);
        _configureWhitelist(activationId, mint ? root : bytes32(0), mint ? bytes32(0) : root);
    }

    function _configureWhitelist(bytes32 activationId, bytes32 mintRoot, bytes32 renewRoot) private {
        vm.prank(address(controller));
        whitelistRule.configure(
            activationId, abi.encode(WhitelistRule.Params({mintRoot: mintRoot, renewRoot: renewRoot}))
        );
    }

    function _configureReservationForClaim(bytes32 activationId, ReservationRule.Claim memory claim) private {
        _configureReservation(activationId, reservationRule.leaf(claim));
    }

    function _configureReservation(bytes32 activationId, bytes32 root) private {
        vm.prank(address(controller));
        reservationRule.configure(activationId, abi.encode(ReservationRule.Params({root: root})));
    }

    function _whitelistClaim(string memory label) private view returns (WhitelistRule.Claim memory claim) {
        claim.labelHash = keccak256(bytes(label));
        claim.account = accounts.buyer.addr;
        claim.mintable = true;
        claim.proof = new bytes32[](0);
    }

    function _reservationClaim(string memory label) private view returns (ReservationRule.Claim memory claim) {
        claim.labelHash = keccak256(bytes(label));
        claim.account = accounts.buyer.addr;
        claim.mintable = true;
        claim.proof = new bytes32[](0);
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
