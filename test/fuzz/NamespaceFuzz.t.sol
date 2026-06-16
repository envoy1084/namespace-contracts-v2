// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermissionedRegistry} from "@ensv2/registry/interfaces/IPermissionedRegistry.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {LengthBasedPricing} from "src/modules/pricing/LengthBasedPricing.sol";
import {ERC20SplitProcessor} from "src/modules/processors/ERC20SplitProcessor.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract NamespaceFuzzTest is NamespaceSetUp {
    LengthBasedPricing internal lengthPricing;
    ERC20SplitProcessor internal splitProcessor;

    function setUp() public override {
        super.setUp();
        lengthPricing = LengthBasedPricing(_deployModule(address(new LengthBasedPricing())));
        splitProcessor = ERC20SplitProcessor(_deployModule(address(new ERC20SplitProcessor())));

        vm.startPrank(accounts.owner.addr);
        controller.setModuleApproval(controller.MODULE_KIND_PRICING(), address(lengthPricing), true);
        controller.setModuleApproval(controller.MODULE_KIND_PROCESSOR(), address(splitProcessor), true);
        vm.stopPrank();
    }

    function testFuzz_mint_registersBoundedLabelAndDuration(bytes32 seed, uint64 duration) public {
        duration = uint64(bound(duration, 1, 10 * 365 days));
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
        lengthPricing.configure(
            activationId,
            abi.encode(
                LengthBasedPricing.Params({
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

        NamespaceTypes.Price memory quoted =
            lengthPricing.quoteMint(ctx, NamespaceTypes.Price({token: address(0), amount: 0}), "");

        uint256 expectedRate = labelLength == 1 ? firstRate : labelLength == 2 ? middleRate : lastRate;
        assertEq(quoted.token, address(token));
        assertEq(quoted.amount, expectedRate * duration);
    }

    function testFuzz_erc20SplitConservesPayment(uint16 aliceBps, uint128 amount) public {
        aliceBps = uint16(bound(aliceBps, 0, 10_000));
        uint16 treasuryBps = uint16(10_000 - aliceBps);

        bytes32 activationId = keccak256("activation");
        ERC20SplitProcessor.Split[] memory splits = new ERC20SplitProcessor.Split[](2);
        splits[0] = ERC20SplitProcessor.Split({recipient: accounts.alice.addr, bps: aliceBps});
        splits[1] = ERC20SplitProcessor.Split({recipient: accounts.treasury.addr, bps: treasuryBps});

        vm.prank(address(controller));
        splitProcessor.configure(activationId, abi.encode(splits));

        token.mint(address(splitProcessor), amount);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        vm.prank(address(controller));
        splitProcessor.processMint(ctx, NamespaceTypes.Price({token: address(token), amount: amount}), "");

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
