// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol"; // For CREATE2 address computation and EIP-1167 deployment
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Interface for the wallet implementation's initializer
interface IWallet {
    function initialize(
        address owner,
        address backendSigner,
        address entryPoint,
        bytes32 initialDeploymentSalt
    ) external;
}

/**
 * @title WalletFactory
 * @author Ethereum Córdoba
 * @notice Factory contract to deploy smart contract wallets (proxies).
 * Deploys EIP-1167 minimal proxies pointing to a fixed implementation.
 * Initializes the wallet with owner info and the trusted backend signer address.
 * Only the owner (deployer or transferred owner) can create new accounts.
 * @dev Inherits Ownable to restrict account creation to the owner.
 */
// Inherit Ownable
contract WalletFactory is Ownable {
    using Address for address;

    /**
     * @notice The address of the master Wallet implementation contract.
     */
    address public immutable WALLET_IMPLEMENTATION;

    /**
     * @notice Emitted when a new wallet proxy is created.
     * @param walletAddress The address of the newly deployed wallet proxy.
     * @param owner An identifier for the owner (could be derived from userId).
     * @param backendSigner The address authorized to sign UserOps for this wallet.
     * @param salt The salt used for CREATE2 deployment.
     */
    event WalletCreated(
        address indexed walletAddress,
        address indexed owner,
        address indexed backendSigner,
        uint256 salt
    );

    /**
     * @param _walletImplementation The address of the singleton Wallet logic contract.
     */
     // Call Ownable constructor setting deployer as owner
    constructor(address _walletImplementation) Ownable(msg.sender) {
        require(_walletImplementation.code.length > 0, "Factory: Implementation must be a contract");
        WALLET_IMPLEMENTATION = _walletImplementation;
    }

    /**
     * @notice Deploys a new Wallet proxy using CREATE2 and initializes it.
     * Can only be called by the owner of the factory contract.
     * @param owner An identifier for the owner of the wallet.
     * @param backendSigner The address that is authorized to sign UserOperations via validateUserOp.
     * @param entryPoint The address of the ERC-4337 EntryPoint contract.
     * @param salt A unique value combined with owner to ensure deterministic address.
     * @return deployedAddress The address of the newly created wallet proxy.
     */
    function createAccount(
        address owner,
        address backendSigner,
        address entryPoint,
        uint256 salt
    )
        external
        onlyOwner // onlyOwner modifier
        returns (address deployedAddress)
    {
        // --- Input Validation ---
        require(owner != address(0), "Factory: Invalid owner");
        require(backendSigner != address(0), "Factory: Invalid backend signer");
        require(entryPoint != address(0), "Factory: Invalid EntryPoint");

        // --- Deployment ---
        // Deploy the EIP-1167 minimal proxy using Clones.cloneDeterministic
        deployedAddress = Clones.cloneDeterministic(WALLET_IMPLEMENTATION, bytes32(salt));

        // --- Initialization ---
        // Initialize the newly deployed wallet proxy
        try IWallet(deployedAddress).initialize(
            owner,
            backendSigner,
            entryPoint,
            bytes32(salt)
        ) {}
        catch {
            revert("Factory: Wallet initialization failed");
        }

        // --- Event Emission ---
        emit WalletCreated(deployedAddress, owner, backendSigner, salt);
    }

    /**
     * @notice Computes the deterministic address where a wallet will be deployed.
     * Useful for off-chain prediction.
     * @param salt The salt that will be used in createAccount.
     * @return predictedAddress The computed CREATE2 address.
     */
    function getDeploymentAddress(uint256 salt) public view returns (address predictedAddress) {
        predictedAddress = Clones.predictDeterministicAddress(
            WALLET_IMPLEMENTATION,
            bytes32(salt),
            address(this) // Factory address is the deployer via CREATE2
        );
    }

    // Note: Ownable provides owner(), transferOwnership() and renounceOwnership() functions.
}
