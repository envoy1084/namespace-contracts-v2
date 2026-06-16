// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LabelClassPricing} from "src/modules/pricing/LabelClassPricing.sol";

/// @title OnlyNumberPricing
/// @notice Adds a premium when the complete label is ASCII number-only.
contract OnlyNumberPricing is LabelClassPricing {
    function labelClass() public pure override returns (LabelClass) {
        return LabelClass.NUMBER;
    }
}
