# Security findings for ***simple-defi-farm***

## ***Disclaimer***
```
This security review is provided for educational purposes only, with the objective of highlighting common vulnerabilities and demonstrating security best practices. This analysis does not constitute a formal, exhaustive, or professional security audit.

The findings presented are not guaranteed to be a complete list of all potential issues. The code discussed should not be used in a production environment without first undergoing a comprehensive, professional security audit.
```

## ***simple-defi-farm***

* [Repo: simple-defi-farm](https://github.com/JuliaGastellu/simple-defi-farm)
* [Commit hash: afae9848d66c51d0ea9c36cedd163fa8420eb0ce](https://github.com/JuliaGastellu/simple-defi-farm/commit/afae9848d66c51d0ea9c36cedd163fa8420eb0ce)
* [Doc: Checks-Effects-Interactions pattern](https://docs.soliditylang.org/en/latest/security-considerations.html)
* Check `***Foundry test:***` for PoC details

## ***Security Findings***
## [H-1] Unbounded loop in distributeRewardsAll leads to permanent denial of service

The `distributeRewardsAll()` function iterates through the `stakerAddresses` array to update rewards for every staker. This array grows with each new unique depositor and is never pruned. As the number of stakers increases, the gas cost to execute this loop will inevitably exceed the block gas limit.

This pattern is a well-known anti-pattern in smart contract development as it creates a Denial of Service (DoS) vector that can render a core feature of the contract permanently unusable.

```Solidity
// TokenFarm.sol
function distributeRewardsAll() external onlyOwner {
@>  for (uint256 i = 0; i < stakerAddresses.length; i++) { // <-- Unbounded loop
        address stakerAddr = stakerAddresses[i];
        if (stakers[stakerAddr].isStaking) {
            distributeRewards(stakerAddr);
        }
    }
    emit RewardsDistributed();
}
```

### Impact

The owner will be unable to call `distributeRewardsAll()` once the staker count is sufficiently high, permanently breaking this function. While individual users can still trigger their own reward updates, this core administrative function will be lost forever, and the intended purpose of distributing rewards to all stakers at once will be impossible.

### Proof of Concept

1. A large number of unique user accounts (e.g., 2,000) each call deposit() with a small amount of LPToken. Each call adds a new address to the stakerAddresses array.
2. The owner attempts to call distributeRewardsAll() to update rewards for everyone.
3. The transaction begins executing the for loop, but the cumulative gas cost of iterating through thousands of addresses (each iteration performing at least one SLOAD operation) exceeds the block's gas limit.
4. The transaction reverts. Any subsequent attempt to call this function will also fail, as the array size will never decrease.

***Foundry test:*** `forge test --mt test_GasUsageExceedsBlockLimit`

### Recommended Mitigation

The function `distributeRewardsAll()` should be removed entirely. The contract already facilitates a "pull" pattern, where each user's rewards are calculated and updated when they interact with the deposit, withdraw, or claimRewards functions. This approach is more scalable and not vulnerable to this DoS attack.

```diff
// SPDX-License-Identifier: MIT
 pragma solidity ^0.8.22;
 
 // ... imports
 
 contract TokenFarm {
     // ... contract code
 
     function claimRewards() external onlyStaker { 
         // ...
     }
 
-    function distributeRewardsAll() external onlyOwner {
-        for (uint256 i = 0; i < stakerAddresses.length; i++) {
-            address stakerAddr = stakerAddresses[i];
-            if (stakers[stakerAddr].isStaking) {
-                distributeRewards(stakerAddr);
-            }
-        }
-        emit RewardsDistributed();
-    }
-
     function distributeRewards(address beneficiary) private {
         // ...
     }
 }
```

## [H-2] Reentrancy in deposit allows state corruption

The `deposit()` function does not follow the `Checks-Effects-Interactions (CEI) pattern`. It performs an external call via `lpToken.transferFrom()` before updating the staker's balance and other state variables.

If the `lpToken` were a malicious contract (or an ERC777 token with hooks), an attacker could execute a re-entrant call back into the deposit function. Because the state (`stakingBalance`) from the first call isn't updated until after the external call, the contract's state can be corrupted during the re-entrant call.

```solidity
// TokenFarm.sol
function deposit(uint256 _amount) external {
    // ...
    distributeRewards(msg.sender);

@>  bool sent = lpToken.transferFrom(msg.sender, address(this), _amount); // <-- INTERACTION
    require(sent, "Transferencia LPToken fallo");

@>  if (!user.hasStaked) { // <-- EFFECTS
@>      user.hasStaked = true;
@>      stakerAddresses.push(msg.sender);
@>  }
@>
@>  user.stakingBalance += _amount;
@>  totalStakingBalance += _amount;
@>  user.isStaking = true;
    // ...
}
```

### Impact

An attacker can cause the contract's state to become inconsistent. While a direct drain is not immediately obvious with the current logic, violating the CEI pattern is a high-severity flaw that often becomes exploitable in combination with other functions or future code updates. It fundamentally breaks the atomic nature of the deposit logic.

Not every reentrancy vulnerability leads to a direct theft of funds like the famous DAO hack. In this contract, a simple re-entry just causes the logic to fail. However, it's still a high-severity flaw because the potential for exploit is there. A future code change could inadvertently make this dormant vulnerability highly profitable. For example, if the contract gave a special bonus reward for every 100th deposit, an attacker could use this reentrancy to manipulate the deposit count.

### Proof of Concept

1. An attacker creates a malicious ERC20 token contract with a hook in its transferFrom function that calls back to `TokenFarm.deposit()`.
2. The attacker calls `TokenFarm.deposit()` with their malicious token.
3. TokenFarm calls `maliciousToken.transferFrom()`.
4. The malicious token's hook triggers and re-enters `TokenFarm.deposit()`.
5. At this point, the attacker's `stakingBalance` from the initial call is still 0, but the contract has already received the tokens. The re-entrant call will now execute its logic based on this inconsistent state, potentially leading to incorrect reward calculations or other exploits.

***Foundry test:*** `forge test --mt test_RevertIf_DepositIsReentrant`

### Recommended Mitigation

Strictly adhere to the `Checks-Effects-Interactions` pattern. All state changes (Effects) must be performed before making any external calls (Interactions).

```diff
function deposit(uint256 _amount) external {
         require(_amount > 0, "Monto debe ser mayor a 0");
         Staker storage user = stakers[msg.sender];
         distributeRewards(msg.sender);
 
+        // EFFECTS
+        if (!user.hasStaked) {
+            user.hasStaked = true;
+            stakerAddresses.push(msg.sender);
+        }
+
+        user.stakingBalance += _amount;
+        totalStakingBalance += _amount;
+        user.isStaking = true;
+        if (user.checkpoint == 0) {
+            user.checkpoint = block.number;
+        }
+
-        bool sent = lpToken.transferFrom(msg.sender, address(this), _amount);
-        require(sent, "Transferencia LPToken fallo");
-
-        if (!user.hasStaked) {
-            user.hasStaked = true;
-            stakerAddresses.push(msg.sender);
-        }
-
-        user.stakingBalance += _amount;
-        totalStakingBalance += _amount;
-        user.isStaking = true;
-        if (user.checkpoint == 0) {
-            user.checkpoint = block.number;
-        }
+        // INTERACTION
+        bool sent = lpToken.transferFrom(msg.sender, address(this), _amount);
+        require(sent, "Transferencia LPToken fallo");
 
         emit Deposit(msg.sender, _amount);
     }
```

## [H-3] Reward calculation can be manipulated by flash loans to steal rewards

The reward calculation in `distributeRewards` is based on the user's instantaneous share of the total staking balance (`user.stakingBalance * 1e18 / totalStakingBalance`). This model is highly susceptible to manipulation.

### Impact

An attacker can use a `flash loan` to borrow a massive amount of `LPTokens`, deposit them to temporarily control a vast majority of the staking pool, and pass a small amount of time (e.g., one block) to accrue a disproportionately large share of the rewards. This drains the rewards that should have gone to legitimate, long-term stakers.

### Proof of Concept

1. The `TokenFarm` has a `totalStakingBalance` of 1,000 LP tokens from legitimate users.
2. An attacker uses a flash loan to borrow 999,000 LP tokens.
3. Within the flash loan transaction, the attacker calls `deposit(999000)`. Their checkpoint is updated. The `totalStakingBalance` is now 1,000,000 LP tokens, and the attacker owns 99.9% of it.
4. The attacker waits for one block to pass.
5. In the next block, the attacker calls `withdraw()`. The `distributeRewards` function is triggered, calculating a reward for the attacker based on their 99.9% share for that one block.
6. The attacker receives their full principal and the unfairly gained rewards. They then repay the flash loan, having successfully extracted value from the protocol.

***Foundry test:*** `forge test --mt test_FlashLoanAttack_StealsUnfairRewards`

### Recommended Mitigation

The reward mechanism should be changed to a more robust model that is resistant to temporary balance manipulation. A standard and recommended approach is to track rewards based on a cumulative rewardPerToken value. This involves:

1. Tracking an `accruedRewardPerShare` variable that is updated whenever the `totalStakingBalance` changes.
2. Each staker stores a `rewardDebt` value, representing the `accruedRewardPerShare` at the time of their last update.
3. A user's pending rewards are calculated as `(staker.balance * accruedRewardPerShare) - staker.rewardDebt`. This formula ensures rewards are allocated based on both the amount and duration of the stake, making flash loan attacks infeasible.

## [L-1] Unchecked return value on ERC20 transfers can lead to silent failures with non-standard tokens

The contract does not check the boolean return value from `dappToken.transfer()` calls. According to the EIP-20 standard, a transfer can fail by returning false. If this happens, the contract's state would become inconsistent with the token's state.

`Contextual Note`: The severity of this finding has been lowered from Medium to Low because the intended `DAppToken` inherits from a modern OpenZeppelin ERC20 implementation, which reverts on failure instead of returning false. However, the flaw remains in the `TokenFarm` contract itself. If the contract were ever used with a non-reverting ERC20 token, this vulnerability would become critical.

```solidity
// In withdrawFees()
@>      dappToken.transfer(owner, amount);

// In claimRewards()
@>      dappToken.transfer(msg.sender, rewardAfterFee);
```

### Impact

In the unlikely event that dappToken is a non-reverting ERC20 token, a transfer failure would cause a silent loss of funds for the user or the owner, as the protocol would update its state as if the transfer had succeeded.

### Proof of concept

***Foundry test:*** `forge test --mt test_FailsSilently_IfRewardTransferReturnsFalse`

### Recommended Mitigation

To ensure maximum security and adherence to best practices, all external calls should be defensively checked. Wrapping the transfer calls in a require statement makes the contract robust regardless of the specific ERC20 implementation used.

```diff
// In withdrawFees()
-        dappToken.transfer(owner, amount);
+        bool sent = dappToken.transfer(owner, amount);
+        require(sent, "Token transfer failed");

// In claimRewards()
-        dappToken.transfer(msg.sender, rewardAfterFee);
+        bool sent = dappToken.transfer(msg.sender, rewardAfterFee);
+        require(sent, "Token transfer failed");
```
