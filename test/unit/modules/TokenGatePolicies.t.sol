// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20BalanceGatePolicy} from "src/modules/policies/ERC20BalanceGatePolicy.sol";
import {ERC721BalanceGatePolicy} from "src/modules/policies/ERC721BalanceGatePolicy.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";

contract TokenGatePoliciesTest is NamespaceSetUp {
    ERC20BalanceGatePolicy internal erc20Gate;
    ERC721BalanceGatePolicy internal erc721Gate;
    MockERC721 internal nft;

    function setUp() public override {
        super.setUp();
        erc20Gate = new ERC20BalanceGatePolicy(address(controller));
        erc721Gate = new ERC721BalanceGatePolicy(address(controller));
        nft = new MockERC721("Mock NFT", "MNFT");
    }

    function test_erc20Gate_allowsBuyerWithMinimumBalance() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        erc20Gate.configure(
            activationId, abi.encode(ERC20BalanceGatePolicy.Params({token: token, minBalance: 100 ether}))
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;

        erc20Gate.checkMint(ctx, "");
    }

    function test_erc20Gate_revertsWhenBuyerBalanceIsTooLow() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        erc20Gate.configure(
            activationId, abi.encode(ERC20BalanceGatePolicy.Params({token: token, minBalance: 2_000_000 ether}))
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20BalanceGatePolicy.InsufficientERC20Balance.selector,
                activationId,
                accounts.buyer.addr,
                address(token),
                token.balanceOf(accounts.buyer.addr),
                2_000_000 ether
            )
        );
        erc20Gate.checkMint(ctx, "");
    }

    function test_erc20Gate_checksRenewPayer() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        erc20Gate.configure(
            activationId, abi.encode(ERC20BalanceGatePolicy.Params({token: token, minBalance: 100 ether}))
        );

        NamespaceTypes.RenewContext memory ctx;
        ctx.activationId = activationId;
        ctx.payer = accounts.buyer.addr;

        erc20Gate.checkRenew(ctx, "");
    }

    function test_erc721Gate_allowsBuyerWithMinimumBalance() public {
        bytes32 activationId = keccak256("activation");
        nft.mint(accounts.buyer.addr, 1);

        vm.prank(address(controller));
        erc721Gate.configure(activationId, abi.encode(ERC721BalanceGatePolicy.Params({token: nft, minBalance: 1})));

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;

        erc721Gate.checkMint(ctx, "");
    }

    function test_erc721Gate_revertsWhenBuyerBalanceIsTooLow() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        erc721Gate.configure(activationId, abi.encode(ERC721BalanceGatePolicy.Params({token: nft, minBalance: 1})));

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721BalanceGatePolicy.InsufficientERC721Balance.selector,
                activationId,
                accounts.buyer.addr,
                address(nft),
                0,
                1
            )
        );
        erc721Gate.checkMint(ctx, "");
    }

    function test_erc721Gate_checksRenewPayer() public {
        bytes32 activationId = keccak256("activation");
        nft.mint(accounts.buyer.addr, 1);

        vm.prank(address(controller));
        erc721Gate.configure(activationId, abi.encode(ERC721BalanceGatePolicy.Params({token: nft, minBalance: 1})));

        NamespaceTypes.RenewContext memory ctx;
        ctx.activationId = activationId;
        ctx.payer = accounts.buyer.addr;

        erc721Gate.checkRenew(ctx, "");
    }
}
