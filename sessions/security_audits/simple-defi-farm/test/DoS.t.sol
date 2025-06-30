// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {TokenFarm} from "../src/TokenFarm.sol";
import {DAppToken} from "../src/DAppToken.sol";
import {LPToken} from "../src/LPToken.sol";

contract DoSTest is Test {
    TokenFarm public tokenFarm;
    DAppToken public dAppToken;
    LPToken public lpToken;

    address public owner = makeAddr("owner");

    function setUp() public {
        vm.startPrank(owner);
        dAppToken = new DAppToken(owner);
        lpToken = new LPToken(owner);
        tokenFarm = new TokenFarm(dAppToken, lpToken);
        vm.stopPrank();
    }

    // This test proves the Denial of Service (DoS) vulnerability in `distributeRewardsAll`.
    // It shows that as the number of stakers grows, the gas required to run the function
    // will exceed a reasonable block gas limit.
    function test_GasUsageExceedsBlockLimit() public {
        // Set a high number of stakers to simulate a popular contract.
        // This number is chosen to ensure the gas cost will be massive.
        uint256 stakerCount = 1500;
        uint256 depositAmount = 1e18; // 1 LP token

        // This loop simulates each of the 1500 users depositing into the farm.
        for (uint256 i = 0; i < stakerCount; i++) {
            // Create a unique, deterministic address for each staker.
            address staker = vm.addr(uint256(keccak256(abi.encodePacked(i))));

            // The owner mints LP tokens directly to the new staker's address.
            vm.startPrank(owner);
            lpToken.mint(staker, depositAmount);
            vm.stopPrank();

            // The staker now approves the TokenFarm contract to spend their LP tokens
            // and then calls `deposit` to stake them.
            vm.startPrank(staker);
            lpToken.approve(address(tokenFarm), depositAmount);
            tokenFarm.deposit(depositAmount);
            vm.stopPrank();
        }

        // IMPORTANT: We must simulate time passing. Without this, the reward calculation
        // logic would exit early for every user, consuming very little gas.
        vm.roll(block.number + 1);

        // The owner will now attempt to call the vulnerable function.
        vm.prank(owner);

        // We record the amount of gas available *before* the function call.
        uint256 gasStart = gasleft();
        // Call the function that contains the unbounded loop.
        tokenFarm.distributeRewardsAll();
        // Calculate the gas consumed by subtracting the remaining gas from the start amount.
        uint256 gasUsed = gasStart - gasleft();

        // Log the result to the console for visibility during the test run.
        console.log("Gas used for %s stakers: %s", stakerCount, gasUsed);

        // We assert that the gas used is greater than
        // the typical Ethereum mainnet block gas limit (~30 million).
        // This proves that the function is too expensive to run in a real environment.
        assertGt(gasUsed, 30_000_000, "Gas used should exceed mainnet block limit");
    }
}
