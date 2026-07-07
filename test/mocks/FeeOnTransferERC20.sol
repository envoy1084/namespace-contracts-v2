// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {MockERC20} from "test/mocks/MockERC20.sol";

contract FeeOnTransferERC20 is MockERC20 {
    uint16 public constant FEE_BPS = 1000;
    uint256 private constant _BPS_DENOMINATOR = 10_000;

    address public immutable feeRecipient;

    constructor(address feeRecipient_) MockERC20("Fee Token", "FEE") {
        feeRecipient = feeRecipient_;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transferWithFee(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transferWithFee(from, to, amount);
        return true;
    }

    function _transferWithFee(address from, address to, uint256 amount) private {
        uint256 fee = (amount * FEE_BPS) / _BPS_DENOMINATOR;
        if (fee != 0) {
            _transfer(from, feeRecipient, fee);
        }
        _transfer(from, to, amount - fee);
    }
}
