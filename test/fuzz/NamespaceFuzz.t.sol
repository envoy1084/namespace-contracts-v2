// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20SplitPaymentModule} from "src/modules/payment/ERC20SplitPaymentModule.sol";
import {LengthPremiumRule} from "src/modules/rules/LengthPremiumRule.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract NamespaceFuzzTest is NamespaceSetUp {
    LengthPremiumRule internal lengthPremiumRule;
    ERC20SplitPaymentModule internal splitPayment;

    function setUp() public override {
        super.setUp();
        lengthPremiumRule = LengthPremiumRule(_deployModule(address(new LengthPremiumRule())));
        splitPayment = ERC20SplitPaymentModule(_deployModule(address(new ERC20SplitPaymentModule())));

        vm.startPrank(accounts.owner.addr);
        controller.setModuleApproval(controller.MODULE_KIND_RULE(), address(lengthPremiumRule), true);
        controller.setModuleApproval(controller.MODULE_KIND_PAYMENT(), address(splitPayment), true);
        vm.stopPrank();
    }

    function testFuzz_mint_registersBoundedLabelAndDuration(bytes32 seed, uint64 duration) public {
        duration = uint64(bound(duration, 1, 365 days));
        string memory label = _label(seed, 3 + (uint256(seed) % 10));

        bytes32 activationId = _activateDefault();
        NamespaceTypes.RuntimeData memory runtimeData = _defaultRuntimeData();

        vm.startPrank(accounts.buyer.addr);
        token.approve(address(erc20Payment), 100 ether);
        uint256 tokenId = controller.mint(activationId, label, duration, runtimeData);
        vm.stopPrank();

        IPermissionedRegistry.State memory state = registry.getState(tokenId);
        assertEq(uint256(state.status), uint256(IPermissionedRegistry.Status.REGISTERED));
        assertEq(state.latestOwner, accounts.buyer.addr);
        assertEq(state.expiry, uint64(block.timestamp) + duration);
    }

    function testFuzz_lengthBasedPricingUsesExpectedBucket(
        uint8 labelLength,
        uint64 duration,
        uint128 firstRate,
        uint128 middleRate,
        uint128 lastRate
    ) public {
        labelLength = uint8(bound(labelLength, 1, 32));
        duration = uint64(bound(duration, 1, 365 days));
        firstRate = uint128(bound(firstRate, 0, 1e18));
        middleRate = uint128(bound(middleRate, 0, 1e18));
        lastRate = uint128(bound(lastRate, 0, 1e18));

        bytes32 activationId = keccak256("activation");
        uint128[] memory mintRates = new uint128[](3);
        mintRates[0] = firstRate;
        mintRates[1] = middleRate;
        mintRates[2] = lastRate;
        uint128[] memory renewRates = new uint128[](1);
        renewRates[0] = 1;

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

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.label = _label(bytes32(uint256(labelLength)), labelLength);
        ctx.duration = duration;

        NamespaceTypes.RuleOutput memory output = lengthPremiumRule.evaluateMint(ctx, "");

        uint256 expectedRate = labelLength == 1 ? firstRate : labelLength == 2 ? middleRate : lastRate;
        assertEq(uint256(output.priceOp), uint256(NamespaceTypes.PriceOp.ADD));
        assertEq(output.token, address(token));
        assertEq(output.amount, expectedRate * duration);
    }

    function testFuzz_erc20SplitConservesPayment(uint16 aliceBps, uint128 amount) public {
        aliceBps = uint16(bound(aliceBps, 0, 10_000));
        uint16 treasuryBps = uint16(10_000 - aliceBps);

        bytes32 activationId = keccak256("activation");
        ERC20SplitPaymentModule.Split[] memory splits = new ERC20SplitPaymentModule.Split[](2);
        splits[0] = ERC20SplitPaymentModule.Split({recipient: accounts.alice.addr, bps: aliceBps});
        splits[1] = ERC20SplitPaymentModule.Split({recipient: accounts.treasury.addr, bps: treasuryBps});

        vm.prank(address(controller));
        splitPayment.configure(
            activationId, abi.encode(ERC20SplitPaymentModule.Params({token: address(token), splits: splits}))
        );

        token.mint(accounts.buyer.addr, amount);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.payer = accounts.buyer.addr;

        vm.prank(accounts.buyer.addr);
        token.approve(address(splitPayment), amount);

        vm.prank(address(controller));
        splitPayment.collectMint(ctx, NamespaceTypes.Price({token: address(token), amount: amount}), "");

        uint256 expectedAlice = (uint256(amount) * aliceBps) / 10_000;
        assertEq(token.balanceOf(accounts.alice.addr), expectedAlice);
        assertEq(token.balanceOf(accounts.treasury.addr), uint256(amount) - expectedAlice);
    }

    function _label(bytes32 seed, uint256 length) private pure returns (string memory) {
        bytes memory label = new bytes(length);
        for (uint256 i; i < length; ++i) {
            label[i] = bytes1(uint8(97 + (uint8(seed[i % 32]) % 26)));
        }
        return string(label);
    }
}
