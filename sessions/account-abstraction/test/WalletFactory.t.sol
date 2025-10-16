// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {WalletFactory} from "../src/WalletFactory.sol";
import {WalletImplementation} from "../src/WalletImplementation.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

// Imports for custom errors
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title WalletFactoryTest
 * @author Ethereum Córdoba
 * @notice Test suite for the WalletFactory contract.
 * @dev Covers demo for account creation, state initialization, and some failure cases.
 */
contract WalletFactoryTest is Test {
    // --- State Variables ---
    WalletImplementation internal implementation;
    WalletFactory internal factory;

    // --- Test Actors ---
    address internal constant FACTORY_OWNER = address(0x100); // -> 0x0000000000000000000000000000000000000100 -> address = 20-byte (40-character hexadecimal)
    address internal constant WALLET_OWNER = address(0x200);
    address internal constant BACKEND_SIGNER = address(0x300);
    address internal constant RANDOM_CALLER = address(0x400);

    // --- Constants ---
    address internal constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032; // v0.7
    uint256 internal constant DEPLOYMENT_SALT = 12345;

    // --- Setup ---
    function setUp() public {
        // Deploy the master implementation contract
        implementation = new WalletImplementation();

        // Deploy the factory, setting the caller as the owner
        vm.prank(FACTORY_OWNER);
        factory = new WalletFactory(address(implementation));
    }

    // --- Test Cases ---
    function test_Success_CreateAccount() public {
        address predictedAddress = factory.getDeploymentAddress(DEPLOYMENT_SALT);
        assertTrue(predictedAddress != address(0), "Prediction should not be zero address");

        vm.expectEmit(true, true, true, true, address(factory));
        emit WalletFactory.WalletCreated(predictedAddress, WALLET_OWNER, BACKEND_SIGNER, DEPLOYMENT_SALT);

        vm.prank(FACTORY_OWNER);
        address deployedAddress = factory.createAccount(
            WALLET_OWNER,
            BACKEND_SIGNER,
            ENTRY_POINT,
            DEPLOYMENT_SALT
        );

        assertEq(deployedAddress, predictedAddress, "Deployed address must match prediction");
        assertTrue(deployedAddress.code.length > 0, "Deployed contract should have code");

        WalletImplementation walletProxy = WalletImplementation(payable(deployedAddress));
        assertEq(walletProxy.owner(), WALLET_OWNER, "Owner mismatch");
        assertEq(walletProxy.backendSigner(), BACKEND_SIGNER, "Backend signer mismatch");
        assertEq(address(walletProxy.entryPoint()), ENTRY_POINT, "EntryPoint mismatch");
        assertEq(uint256(walletProxy.deploymentSalt()), DEPLOYMENT_SALT, "Deployment salt mismatch");
    }

    /**
     * @notice Ensures that only the owner of the factory can create new accounts.
     */
    function test_Fail_CreateAccount_FromNonOwner() public {
        vm.prank(RANDOM_CALLER);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, RANDOM_CALLER));
        factory.createAccount(WALLET_OWNER, BACKEND_SIGNER, ENTRY_POINT, DEPLOYMENT_SALT);
    }

    function test_Fail_CreateAccount_WithZeroAddressOwner() public {
        vm.prank(FACTORY_OWNER);
        vm.expectRevert("Factory: Invalid owner");
        factory.createAccount(address(0), BACKEND_SIGNER, ENTRY_POINT, DEPLOYMENT_SALT);
    }
    
    /**
     * @notice Verifies that the initialize function on a deployed proxy cannot be called a second time.
     */
    function test_Fail_Reinitialization() public {
        vm.prank(FACTORY_OWNER);
        address deployedAddress = factory.createAccount(
            WALLET_OWNER,
            BACKEND_SIGNER,
            ENTRY_POINT,
            DEPLOYMENT_SALT
        );

        WalletImplementation walletProxy = WalletImplementation(payable(deployedAddress));

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        walletProxy.initialize(RANDOM_CALLER, RANDOM_CALLER, IEntryPoint(ENTRY_POINT), bytes32(uint256(999)));
    }
}
