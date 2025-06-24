// SPDX-License-Identifier: MIT
// Ethereum Cordoba for https://remix.ethereum.org/
pragma solidity ^0.8.20;

import {EIP712} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/utils/cryptography/ECDSA.sol";
import {Nonces} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/utils/Nonces.sol";

/**
 * @title EIP712EthereumCordoba
 * @author Ethereum Córdoba
 * @notice This contract demonstrates a full lifecycle of EIP-712 for meta-transactions.
 * It allows a designated signer to authorize a state change (setting a value)
 * by signing a structured message off-chain. Another account (a "relayer")
 * can then submit this signature to the contract to execute the transaction,
 * paying the gas fee on behalf of the signer.
 */
contract EIP712EthereumCordoba is EIP712, Nonces {
    // --- State Variables ---

    // Mapping to store a value for each user, updated via meta-transaction.
    mapping(address => uint256) public userValues;

    // --- EIP-712 Typed Data Definition ---

    // The TYPEHASH for the structured message.
    bytes32 private constant SET_VALUE_TYPEHASH =
        keccak256("SetValue(uint256 value,uint256 nonce)");

    // --- Events ---

    // Emitted when a value is successfully set via a meta-transaction.
    event ValueSet(address indexed signer, uint256 value);

    // --- Constructor ---

    /**
     * @notice Sets up the EIP-712 domain separator.
     * @param _name The name of the dApp or protocol.
     * @param _version The version of the message format.
     */
    constructor(
        string memory _name,
        string memory _version
    ) EIP712(_name, _version) {}

    // --- Public Functions ---

    /**
     * @notice The main function to execute a meta-transaction.
     * @dev A relayer calls this function with a signed message from the user.
     * It verifies the signature, consumes the nonce, and performs the state change.
     * @param signer The address of the user who signed the message.
     * @param value The value the user wants to set.
     * @param signature The EIP-712 signature from the signer.
     */
    function execute(
        address signer,
        uint256 value,
        bytes calldata signature
    ) public {
        // 1. Hash the structured message with the current nonce.
        bytes32 digest = _hash(signer, value);
        
        // Nonce must be consumed before verification to prevent replay attacks.
        _useNonce(signer);

        // 2. Recover the address from the signature and the digest.
        address recoveredSigner = ECDSA.recover(digest, signature);
        require(
            recoveredSigner != address(0),
            "ECDSA: invalid signature"
        );

        // 3. Verify that the recovered address matches the intended signer.
        require(
            recoveredSigner == signer,
            "EIP712EthereumCordoba: Invalid signer"
        );

        // 4. If the signature is valid, execute the state change.
        userValues[signer] = value;
        emit ValueSet(signer, value);
    }

    // --- Internal Functions ---

    /**
     * @notice Hashes the typed data structure.
     * @dev This function implements the EIP-712 signing logic.
     * @param _signer The address of the user authorizing the action.
     * @param _value The value to be set.
     * @return digest The EIP-712 digest to be signed.
     */
    function _hash(
        address _signer,
        uint256 _value
    ) internal view returns (bytes32) {
        // Nonce is fetched directly inside the hash to ensure the signed
        // data perfectly matches what the contract expects.
        uint256 currentNonce = nonces(_signer);

        // Encode the struct data.
        bytes32 structHash = keccak256(
            abi.encode(SET_VALUE_TYPEHASH, _value, currentNonce)
        );

        // Combine with the domain separator and return the final digest.
        return _hashTypedDataV4(structHash);
    }

    // --- View Functions ---

    /**
     * @notice A view function to get the current nonce for a user.
     * @dev This is needed for off-chain clients to construct the correct message to sign.
     * @param user The address of the user.
     * @return The current nonce.
     */
    function getNonce(address user) external view returns (uint256) {
        return nonces(user);
    }

    function getChainId() public view returns (uint256) {
        return block.chainid;
    }
}
