// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {ERC20SplitProcessor} from "src/modules/processors/ERC20SplitProcessor.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract ERC20SplitProcessorTest is NamespaceSetUp {
    ERC20SplitProcessor internal processor;

    function setUp() public override {
        super.setUp();
        processor = ERC20SplitProcessor(_deployModule(address(new ERC20SplitProcessor())));
    }

    function test_processMint_splitsProcessorBalance() public {
        bytes32 activationId = keccak256("activation");
        ERC20SplitProcessor.Split[] memory splits = new ERC20SplitProcessor.Split[](2);
        splits[0] = ERC20SplitProcessor.Split({recipient: accounts.alice.addr, bps: 9000});
        splits[1] = ERC20SplitProcessor.Split({recipient: accounts.treasury.addr, bps: 1000});

        vm.prank(address(controller));
        processor.configure(activationId, abi.encode(splits));

        token.mint(address(processor), 1000);

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        vm.prank(address(controller));
        processor.processMint(ctx, NamespaceTypes.Price({token: address(token), amount: 1000}), "");

        assertEq(token.balanceOf(accounts.alice.addr), 900);
        assertEq(token.balanceOf(accounts.treasury.addr), 100);
    }
}
