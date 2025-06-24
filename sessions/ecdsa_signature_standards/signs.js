// Ethereum Córdoba
// This script generates an EIP-712 signature for the meta-transaction contract.

(async () => {
    try {
        console.log("Starting signature generation script...");

        // Change contract address here
        const contractAddress = "0x7EF2e0048f5bAeDe046f6BF797943daF4ED8CB47";

        // 1. Contract ABI
        const contractABI = [
            {
                "inputs": [
                    {
                        "internalType": "string",
                        "name": "_name",
                        "type": "string"
                    },
                    {
                        "internalType": "string",
                        "name": "_version",
                        "type": "string"
                    }
                ],
                "stateMutability": "nonpayable",
                "type": "constructor"
            },
            {
                "inputs": [],
                "name": "ECDSAInvalidSignature",
                "type": "error"
            },
            {
                "inputs": [
                    {
                        "internalType": "uint256",
                        "name": "length",
                        "type": "uint256"
                    }
                ],
                "name": "ECDSAInvalidSignatureLength",
                "type": "error"
            },
            {
                "inputs": [
                    {
                        "internalType": "bytes32",
                        "name": "s",
                        "type": "bytes32"
                    }
                ],
                "name": "ECDSAInvalidSignatureS",
                "type": "error"
            },
            {
                "inputs": [
                    {
                        "internalType": "address",
                        "name": "account",
                        "type": "address"
                    },
                    {
                        "internalType": "uint256",
                        "name": "currentNonce",
                        "type": "uint256"
                    }
                ],
                "name": "InvalidAccountNonce",
                "type": "error"
            },
            {
                "inputs": [],
                "name": "InvalidShortString",
                "type": "error"
            },
            {
                "inputs": [
                    {
                        "internalType": "string",
                        "name": "str",
                        "type": "string"
                    }
                ],
                "name": "StringTooLong",
                "type": "error"
            },
            {
                "anonymous": false,
                "inputs": [],
                "name": "EIP712DomainChanged",
                "type": "event"
            },
            {
                "anonymous": false,
                "inputs": [
                    {
                        "indexed": true,
                        "internalType": "address",
                        "name": "signer",
                        "type": "address"
                    },
                    {
                        "indexed": false,
                        "internalType": "uint256",
                        "name": "value",
                        "type": "uint256"
                    }
                ],
                "name": "ValueSet",
                "type": "event"
            },
            {
                "inputs": [],
                "name": "eip712Domain",
                "outputs": [
                    {
                        "internalType": "bytes1",
                        "name": "fields",
                        "type": "bytes1"
                    },
                    {
                        "internalType": "string",
                        "name": "name",
                        "type": "string"
                    },
                    {
                        "internalType": "string",
                        "name": "version",
                        "type": "string"
                    },
                    {
                        "internalType": "uint256",
                        "name": "chainId",
                        "type": "uint256"
                    },
                    {
                        "internalType": "address",
                        "name": "verifyingContract",
                        "type": "address"
                    },
                    {
                        "internalType": "bytes32",
                        "name": "salt",
                        "type": "bytes32"
                    },
                    {
                        "internalType": "uint256[]",
                        "name": "extensions",
                        "type": "uint256[]"
                    }
                ],
                "stateMutability": "view",
                "type": "function"
            },
            {
                "inputs": [
                    {
                        "internalType": "address",
                        "name": "signer",
                        "type": "address"
                    },
                    {
                        "internalType": "uint256",
                        "name": "value",
                        "type": "uint256"
                    },
                    {
                        "internalType": "bytes",
                        "name": "signature",
                        "type": "bytes"
                    }
                ],
                "name": "execute",
                "outputs": [],
                "stateMutability": "nonpayable",
                "type": "function"
            },
            {
                "inputs": [
                    {
                        "internalType": "address",
                        "name": "user",
                        "type": "address"
                    }
                ],
                "name": "getNonce",
                "outputs": [
                    {
                        "internalType": "uint256",
                        "name": "",
                        "type": "uint256"
                    }
                ],
                "stateMutability": "view",
                "type": "function"
            },
            {
                "inputs": [
                    {
                        "internalType": "address",
                        "name": "owner",
                        "type": "address"
                    }
                ],
                "name": "nonces",
                "outputs": [
                    {
                        "internalType": "uint256",
                        "name": "",
                        "type": "uint256"
                    }
                ],
                "stateMutability": "view",
                "type": "function"
            },
            {
                "inputs": [
                    {
                        "internalType": "address",
                        "name": "",
                        "type": "address"
                    }
                ],
                "name": "userValues",
                "outputs": [
                    {
                        "internalType": "uint256",
                        "name": "",
                        "type": "uint256"
                    }
                ],
                "stateMutability": "view",
                "type": "function"
            }
        ];
      
        // 2. Get accounts from the wallet
        const accounts = await web3.eth.getAccounts();
        const signerAddress = accounts[0]; // Using the first account as the signer
        console.log("Signer Address (Account 1):", signerAddress);
        
        // 3. Create a contract instance to interact with
        const contract = new web3.eth.Contract(contractABI, contractAddress);

        // 4. Define the transaction data
        const valueToSet = 5000;
        const nonce = await contract.methods.getNonce(signerAddress).call();
        const domainData = await contract.methods.eip712Domain().call();
        const chainId = domainData.chainId;

        console.log(`Data to sign: value=${valueToSet}, nonce=${nonce}, chainId=${chainId}`);

        // 5. Construct the EIP-712 typed data object
        const typedData = {
            types: {
                EIP712Domain: [
                    { name: 'name', type: 'string' },
                    { name: 'version', type: 'string' },
                    { name: 'chainId', type: 'uint256' },
                    { name: 'verifyingContract', type: 'address' },
                ],
                SetValue: [
                    { name: 'value', type: 'uint256' },
                    { name: 'nonce', type: 'uint256' },
                ],
            },
            primaryType: 'SetValue',
            domain: {
                name: 'EIP712EthereumCordoba',
                version: '1',
                chainId: chainId.toString(),
                verifyingContract: contractAddress,
            },
            message: {
                value: valueToSet,
                nonce: nonce.toString(),
            },
        };

        // 6. Send the signing request
        const signature = await web3.currentProvider.request({
            method: 'eth_signTypedData_v4',
            params: [signerAddress, typedData],
            from: signerAddress,
        });

        console.log("Generated Signature:", signature);
        console.log("------");
        console.log("You can now use this signature to call the `execute` function.");

    } catch (e) {
        console.error("An error occurred in the script:", e.message);
    }
})();
