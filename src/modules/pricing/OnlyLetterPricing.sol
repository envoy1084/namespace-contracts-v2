// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LabelClassPricing} from "src/modules/pricing/LabelClassPricing.sol";

/// @title OnlyLetterPricing
/// @notice Adds a premium when the complete label is ASCII letter-only.
contract OnlyLetterPricing is LabelClassPricing {
    function labelClass() public pure override returns (LabelClass) {
        return LabelClass.LETTER;
    }
}
