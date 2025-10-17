# ERC-4337 (Account Abstraction)

## To be discussed

* `Onboarding new users`: Normally, to do anything on Ethereum, you first need to buy ETH from an exchange, which is a major barrier. Account Abstraction allows a dApp to sponsor a new user's first few transactions. This creates a seamless "Web2" experience where a user can start interacting immediately without needing to own any cryptocurrency.

* `Improving dApp experience`: For existing users, dApps can choose to pay for gas on their behalf to boost engagement or promote certain features. This removes the friction of approving every transaction and worrying about gas fees, making the application feel smoother and "gasless."

* `Flexible payment options`: Users are no longer forced to pay for gas in ETH. A "paymaster" (a sponsor) can pay the gas fee in ETH on the user's behalf, while the user pays the paymaster back in another token, like USDC. You could have a wallet full of stablecoins and use a dApp without ever needing to own ETH.

* `Enhancing privacy`: A user can create a brand new, unfunded wallet and sign a transaction. A completely separate, unlinked account (a "relayer" or sponsor) can then pick up this signed transaction and pay the gas fee to submit it on-chain. This breaks the on-chain link between where a user gets their funds and how they use their new wallet, significantly improving privacy.

## EIP-1167

`EIP-1167` minimal proxies are a highly gas-efficient method for deploying multiple contract instances that share the same underlying logic. Instead of deploying the full contract code for each user, you deploy a tiny, standardized proxy that delegates all its function calls to a single, master implementation contract.

## Demo - Smart contracts

1. Wallet implementation contract deployed to: `0x323692519ab774631eeDC1950c9a2b454188073c`
2. Wallet factory deployed to: `0x07b00A73983a5E89E69eff71D4CAae43001835B5`
3. Wallet proxy instance address: `0x525629e6efb89D0Bf106cfEdBA2A62F13755D76D` ***(must have ether for the GAS payment)***
4. Simple contract address: `0xf7BF97C4Ae0CBC3E93E8dcb72BCDb4ccfD29c6AB`
5. User operation included in block: 9425416
   - Transaction hash: `0x679cd5d81d5bda0d4e26e76429c05487768793fc220cbc74249a4050bdda3080`

## Links

[ERC-4337 Official Documentation](https://docs.erc4337.io/)
