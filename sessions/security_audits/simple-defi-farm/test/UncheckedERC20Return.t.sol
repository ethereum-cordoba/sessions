// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {TokenFarm} from "../src/TokenFarm.sol";
import {DAppToken} from "../src/DAppToken.sol";
import {LPToken} from "../src/LPToken.sol";
import {AttackDAppToken} from "../src/AttackDAppToken.sol";

contract UncheckedERC20ReturnTest is Test {
    TokenFarm public tokenFarm;
    AttackDAppToken public attackDAppToken;
    LPToken public lpToken;

    address public owner = makeAddr("owner");
    address public staker = makeAddr("staker");

    function setUp() public {
        vm.startPrank(owner);
        // Deploy our special non-reverting token
        attackDAppToken = new AttackDAppToken(owner);
        lpToken = new LPToken(owner);
        // Deploy TokenFarm with the non-reverting token
        tokenFarm = new TokenFarm(DAppToken(address(attackDAppToken)), lpToken);

        // Fund the farm with reward tokens
        attackDAppToken.mint(address(tokenFarm), 1_000_000e18);
        vm.stopPrank();

        // Have a user stake some LP tokens to earn rewards
        vm.startPrank(owner);
        lpToken.mint(staker, 100e18);
        vm.stopPrank();

        vm.startPrank(staker);
        lpToken.approve(address(tokenFarm), 100e18);
        tokenFarm.deposit(100e18);
        vm.stopPrank();
    }

    // This test proves that if a token transfer fails silently,
    // the user's rewards are wiped from the farm's accounting
    // but are never actually received by the user.
    function test_FailsSilently_IfRewardTransferReturnsFalse() public {
        // --- 1. Let time pass for rewards to accrue ---
        vm.roll(block.number + 10);

        // --- 2. Configure the DAppToken to fail the next transfer ---
        vm.prank(owner);
        attackDAppToken.setTransferShouldFail(true);

        // --- 3. The staker attempts to claim rewards ---
        // The transaction will succeed because the return value is not checked.
        vm.prank(staker);
        tokenFarm.claimRewards();

        // --- 4. Assert the state is inconsistent ---
        // Check the staker's reward balance in the farm (should be 0)
        (uint256 stakingBalance, , uint256 pendingRewards, , ) = tokenFarm.stakers(staker);
        assertEq(pendingRewards, 0, "Pending rewards should be reset to 0");

        // Check the staker's actual token balance (should also be 0)
        uint256 stakerTokenBalance = attackDAppToken.balanceOf(staker);
        assertEq(stakerTokenBalance, 0, "Staker should have received no tokens");

        console.log("Vulnerability confirmed: Rewards were zeroed out in the farm but never sent to the staker.");
    }
}
