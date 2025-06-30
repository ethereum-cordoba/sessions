// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {DAppToken} from "../src/DAppToken.sol";

// A non-standard ERC20 that can be configured to return `false` on transfers
// instead of reverting, simulating older or non-compliant tokens.
contract AttackDAppToken is DAppToken {
    bool public shouldTransferFail = false;

    constructor(address _initialOwner) DAppToken(_initialOwner) {}

    // Owner can toggle the transfer failure mode for testing
    function setTransferShouldFail(bool _shouldFail) public onlyOwner {
        shouldTransferFail = _shouldFail;
    }

    // Override the transfer function to implement the silent failure
    function transfer(address to, uint256 amount) public override returns (bool) {
        if (shouldTransferFail) {
            return false; // Fail silently
        }
        return super.transfer(to, amount);
    }
}
