# ECDSA signature standards

## General overview

The `EIP-712` standard enables a powerful pattern known as meta-transactions. This flow allows a user to authorize an on-chain action without needing to send a transaction or pay for gas themselves. It achieves this by separating the authorization of an action from its execution.

The process involves three key roles:

1. `The Signer (User)`: The end-user who wants to interact with the contract. They use their private key to sign a structured, human-readable message that describes their desired action (e.g., "Set value to 5000"). This signing happens off-chain and costs no gas.

2. `The Relayer`: A third-party service or another user who takes the Signer's message and signature. The Relayer wraps this data in a standard blockchain transaction and submits it to the smart contract. The Relayer is the one who pays the gas fee for the transaction.

3. `The Contract`: The smart contract is designed to receive the signed message from the Relayer. It performs a critical verification step:
    a. It reconstructs the exact same structured message that the Signer was supposed to sign.
    b. Using the signature and the reconstructed message, it uses ECDSA.recover to determine which address created the signature.
    c. If the recovered address matches the signer's address, the signature is valid, and the contract executes the action (e.g., updates a value) on behalf of the Signer.

This creates a "gasless" experience for the end-user, significantly improving usability for decentralized applications. The nonce management within the contract is crucial to prevent a relayer from submitting the same valid signature multiple times (a "replay attack").

## Execution Flow for [Remix](https://remix.ethereum.org/)

1. `Compile and deploy`
   1. `EIP712EthereumCordoba.sol` must be placed inside `contracts` folder.
   2. Go to the `Solidity Compiler` tab in Remix.
   3. Select the `EIP712EthereumCordoba.sol` file and click `Compile`.
   4. Go to the `Deploy & Run Transactions` tab.
   5. In the `ACCOUNT dropdown`, make sure you have the first account selected (`Account 1`).
   6. Next to the `Deploy` button, enter the constructor arguments: `EIP712EthereumCordoba,1`.
   7. Click `Deploy`.
   8. A new contract will appear under `Deployed Contracts`. Click the copy icon next to its address to copy it (`verifyingContract: 0x7EF2e0048f5bAeDe046f6BF797943daF4ED8CB47`).

2. `Generate the Signature`
   1. Open the `sign.js`, must be placed inside `scripts` folder.
   2. Make sure the account selected in the ACCOUNT dropdown is still `Account 1` (the signer).
   3. Right-click the `sign.js` file in the file explorer and click `Run`.
   4. The Remix console will now display the Signer Address and the Generated Signature. 
   5. Copy the signature (the long 0x... string).

```bash
Starting signature generation script...
Signer Address (Account 1):
0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
Data to sign: value=5000, nonce=0, chainId=1
Generated Signature:
0x97264116e346d215061f122a6a86c641e4519db97126e8e0f2380a5e9d2906c828b8a039e78285d4bebec33fed25c435448eefbc56402ff501e34a43a0b5f2ab1c
------
You can now use this signature to call the `execute` function.
```

3. `Execute the Meta-Transaction`
   1. Switch accounts. In the `ACCOUNT` dropdown, select the second account (`Account 2`). This account will be the "relayer" and will pay the gas fee.
   2. Go back to the deployed contract's interface under `Deployed Contracts`.
   3. Find the execute function and expand it.
   4. Fill in the parameters:
      1. signer (address): Paste the Signer Address from the console (`Account 1`'s address).
      2. value (uint256): Enter `5000` (the value from the script).
      3. signature (bytes): Paste the Generated Signature you copied from the console.
   5. Click the `transact` button. The transaction will be sent from `Account 2`.

```bash

status	0x1 Transaction mined and execution succeed
transaction hash	0x76e690d9af4c83940e78011df2b783463fe3931a08253049be62958d47f6a822
block hash	0xf8d401200462b8b7f7f3ff9cf11da06a3a73fac5208cdcd9d549af5bac123d5b
block number	13
from	0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
to	EIP712EthereumCordoba.execute(address,uint256,bytes) 0x7EF2e0048f5bAeDe046f6BF797943daF4ED8CB47
gas	86899 gas
transaction cost	75564 gas 
execution cost	52536 gas 
input	0xb61...00000
output	0x
decoded input	{
	"address signer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
	"uint256 value": "5000",
	"bytes signature": "0x97264116e346d215061f122a6a86c641e4519db97126e8e0f2380a5e9d2906c828b8a039e78285d4bebec33fed25c435448eefbc56402ff501e34a43a0b5f2ab1c"
}
decoded output	{}
logs	[
	{
		"from": "0x7EF2e0048f5bAeDe046f6BF797943daF4ED8CB47",
		"topic": "0xf3f57717dff9f5f10af315efdbfadc60c42152c11fc0c3c413bbfbdc661f143c",
		"event": "ValueSet",
		"args": {
			"0": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
			"1": "5000"
		}
	}
]
```

4. `Verify the Outcome`
   1. The transaction in the console should show a green checkmark, indicating it succeeded.
   2. In the deployed contract's UI, find the userValues mapping.
   3. Paste the Signer Address (`Account 1`'s address) into the field and click call.
   4. The result should be `5000`, confirming the state was updated correctly.
   5. If you try to click the transact button on execute again with the same signature, it will fail. This proves the nonce-based replay protection is working.
