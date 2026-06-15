// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {SaleWindowPolicy} from "src/modules/policies/SaleWindowPolicy.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract SaleWindowPolicyTest is NamespaceSetUp {
    function test_checkMint_revertsBeforeStart() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        saleWindowPolicy.configure(
            activationId, abi.encode(SaleWindowPolicy.Params({startTime: uint64(block.timestamp + 1 days), endTime: 0}))
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        vm.expectRevert();
        saleWindowPolicy.checkMint(ctx, "");
    }

    function test_checkMint_allowsInsideWindow() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        saleWindowPolicy.configure(
            activationId,
            abi.encode(
                SaleWindowPolicy.Params({startTime: uint64(block.timestamp), endTime: uint64(block.timestamp + 1 days)})
            )
        );

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;

        saleWindowPolicy.checkMint(ctx, "");
    }
}
