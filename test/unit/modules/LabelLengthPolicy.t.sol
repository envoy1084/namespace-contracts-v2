// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {LabelLengthPolicy} from "src/modules/policies/LabelLengthPolicy.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract LabelLengthPolicyTest is NamespaceSetUp {
    function test_checkMint_revertsWhenTooShort() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        labelLengthPolicy.configure(activationId, abi.encode(LabelLengthPolicy.Params({minLength: 3, maxLength: 6})));

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.label = "ab";

        vm.expectRevert();
        labelLengthPolicy.checkMint(ctx, "");
    }

    function test_checkMint_allowsValidLength() public {
        bytes32 activationId = keccak256("activation");
        vm.prank(address(controller));
        labelLengthPolicy.configure(activationId, abi.encode(LabelLengthPolicy.Params({minLength: 3, maxLength: 6})));

        NamespaceTypes.MintContext memory ctx;
        ctx.activationId = activationId;
        ctx.label = "pay";

        labelLengthPolicy.checkMint(ctx, "");
    }
}
