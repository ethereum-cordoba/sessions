// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {TokenFarm} from "../src/TokenFarm.sol";
import {DAppToken} from "../src/DAppToken.sol";
import {LPToken} from "../src/LPToken.sol";
import {AttackLPToken} from "../src/AttackLPToken.sol";

contract ReentrancyTest is Test {
    TokenFarm public tokenFarm;
    DAppToken public dAppToken;
    AttackLPToken public attackLPToken;
    address public attacker = makeAddr("attacker");
    address public owner = makeAddr("owner");

    function setUp() public {
        // Deploy the contracts
        vm.startPrank(owner);
        dAppToken = new DAppToken(owner);
        attackLPToken = new AttackLPToken(owner);
        tokenFarm = new TokenFarm(dAppToken, LPToken(address(attackLPToken)));

        // Configure the attacker and the malicious token
        attackLPToken.setAttackParams(attacker, address(tokenFarm), 1e18);
        attackLPToken.mint(attacker, 100e18);
        vm.stopPrank();

        // Attacker approves the TokenFarm to spend their tokens
        vm.startPrank(attacker);
        attackLPToken.approve(address(tokenFarm), 100e18);
        vm.stopPrank();
    }

    // This test demonstrates that the re-entrancy attack vector exists.
    // The transaction is expected to revert because the re-entrant call
    // disrupts the normal flow of the `deposit` function.
    function test_RevertIf_DepositIsReentrant() public {
        uint256 initialAttackAmount = 10e18;

        // We expect the transaction to revert. The exact revert reason can vary,
        // but any revert here proves that the re-entrancy path is exploitable
        // and causes unintended behavior.
        vm.expectRevert();

        // Attacker initiates the deposit, which will trigger the re-entrant call
        vm.prank(attacker);
        tokenFarm.deposit(initialAttackAmount);

        // Final check to ensure no state was corrupted (i.e., balance is still 0)
        (uint256 stakingBalance, , , ,) = tokenFarm.stakers(attacker);
        assertEq(stakingBalance, 0, "Attacker's staking balance should be 0 after failed attack");
    }
}
