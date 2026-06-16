// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LabelClassPricing} from "src/modules/pricing/LabelClassPricing.sol";

/// @title OnlyEmojiPricing
/// @notice Adds a premium when the complete label is emoji-only.
contract OnlyEmojiPricing is LabelClassPricing {
    function labelClass() public pure override returns (LabelClass) {
        return LabelClass.EMOJI;
    }
}
