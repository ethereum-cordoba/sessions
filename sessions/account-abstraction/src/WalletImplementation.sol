// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { BaseAccount } from "@account-abstraction/contracts/core/BaseAccount.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title WalletImplementation
 * @author Ethereum Córdoba
 * @notice This is the logic contract for a simple, upgradeable ERC-4337 smart account.
 * Each user gets a proxy that delegates calls to this implementation.
 * It features a primary owner and a secondary 'backendSigner' for operational flexibility.
 */
contract WalletImplementation is BaseAccount, Initializable {
    address public owner;
    address public backendSigner; 
    IEntryPoint private _entryPoint; 
    bytes32 public deploymentSalt;

    // --- Constants ---
    uint256 internal constant SIG_VALIDATION_SUCCESS = 0;
    uint256 internal constant SIG_VALIDATION_FAILED = 1;

    // constructor() {} // empty constructor

    // Initializer function to be called ONCE per proxy by the factory
    function initialize(
        address initialOwner,
        address initialBackendSigner,
        IEntryPoint entryPointAddress,
        bytes32 initialDeploymentSalt
    )
        external
        initializer // Modifier from Initializable to ensure it's called only once per proxy
    {
        require(initialOwner != address(0), "TW: owner cannot be zero address");
        require(initialBackendSigner != address(0), "TW: backendSigner cannot be zero address");
        require(address(entryPointAddress) != address(0), "TW: entryPoint cannot be zero address");

        owner = initialOwner;
        backendSigner = initialBackendSigner; // Set backendSigner for the proxy
        _entryPoint = entryPointAddress;      // Set entryPoint for the proxy
        deploymentSalt = initialDeploymentSalt;
    }

    // --- Required by IAccount and BaseAccount ---

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        virtual
        override
        returns (uint256 validationData)
    {
        _validateNonce(userOp.nonce);

        uint256 sigStatus = _validateSignature(userOp, userOpHash);

        uint160 aggregatorOrValidationStatus;
        if (sigStatus == SIG_VALIDATION_SUCCESS) {
            aggregatorOrValidationStatus = uint160(address(0)); // Use address(0) for success in non-aggregating accounts
        } else {
            aggregatorOrValidationStatus = uint160(address(1)); // Use address(1) for failure in non-aggregating accounts
        }

        // aggregator_or_status (160 bits) | validUntil (48 bits) | validAfter (48 bits)
        // Shift aggregator_or_status by (48+48) = 96 bits.
        // Shift validUntil by 48 bits.
        // validationData = (uint256(aggregatorOrValidationStatus) << 96) | (uint256(validUntil) << 48) | uint256(validAfter);
        // Since validUntil and validAfter are 0, this simplifies to:
        validationData = uint256(aggregatorOrValidationStatus) << 96;

        return validationData;
    }

    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        internal
        virtual
        override
        returns (uint256) // Return 0 for success, 1 for failure internally
    {
        address signer = ECDSA.recover(userOpHash, userOp.signature);

        // Check if the recovered signer address is EITHER the account's owner OR the backendSigner.
        if (signer == owner || signer == backendSigner) {
            return SIG_VALIDATION_SUCCESS; // Return 0
        } else {
            return SIG_VALIDATION_FAILED; // Return 1
        }
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    // --- Execution Function ---
    function execute(address dest, uint256 value, bytes calldata funcCallData)
        external
        virtual
    {
        _requireFromEntryPoint();
        (bool success, bytes memory result) = dest.call{value: value}(funcCallData);
        require(success, string(result));
    }

    receive() external payable {}
}
