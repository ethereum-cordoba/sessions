// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {WalletFactory} from "../src/WalletFactory.sol";

contract CreateWalletInstance is Script {
    // Backend will use to sign UserOps for THIS wallet
    address private constant BACKEND_SIGNER = 0xfd611697b1225bbDe2C47b8615E9f1a1AeBcdbF0; // DO NOT hardcode this value, only for demo!

    // Factory address: the address from deploying DeployWalletFactory.s.sol)
    address private constant FACTORY_ADDRESS = 0x07b00A73983a5E89E69eff71D4CAae43001835B5; // DO NOT hardcode this value, only for demo!    

    address private constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032; //  EntryPoint v0.7+
                                           
    // Deployment Salt => a unique number for THIS specific wallet instance
    // MUST be different for each user wallet you create.
    // Choose a unique, fixed salt for reproducibility.
    bytes32 public constant DEPLOYMENT_SALT = keccak256(abi.encodePacked("my_unique_string_1"));

    function run() external returns (address deployedAddress) {
        // --- Pre-checks ---
        require(FACTORY_ADDRESS != address(0), "Set FACTORY_ADDRESS constant");
        require(BACKEND_SIGNER != address(0), "Set BACKEND_SIGNER constant");
        require(ENTRY_POINT != address(0), "Set ENTRY_POINT constant");

        // Get the owner address for this new wallet (using the script runner's address)
        // In the real backend, this would likely be derived from the userId.
        address owner = msg.sender;
        console.log("Wallet Owner (Script Runner):", owner);
        console.log("Backend Signer:", BACKEND_SIGNER);
        console.log("EntryPoint:", ENTRY_POINT);       
        console.log("Deployment Salt (bytes32):"); // Log the label first
        console.logBytes32(DEPLOYMENT_SALT);  // Then log the bytes32 value

        // Explicitly cast the bytes32 DEPLOYMENT_SALT to uint256 for factory calls
        uint256 saltForFactoryCall = uint256(DEPLOYMENT_SALT);
        console.log("Deployment Salt (uint256 for factory call):", saltForFactoryCall);

        // Get an interface to the deployed factory by casting the address
        // to the imported contract type.
        WalletFactory factory = WalletFactory(FACTORY_ADDRESS);

        // --- Predict address (optional but recommended) ---
        address predictedAddress = factory.getDeploymentAddress(saltForFactoryCall);
        console.log("Predicted Wallet Address:", predictedAddress);

        // --- Execute Deployment ---
        console.log("Sending transaction to factory.createAccount...");
        vm.startBroadcast();

        // Call the factory to create the account (proxy) and initialize it
        // Passes owner, backendSigner, entryPoint, and salt
        deployedAddress = factory.createAccount(
            owner,
            BACKEND_SIGNER,
            ENTRY_POINT,
            saltForFactoryCall
        );

        vm.stopBroadcast();
        console.log("--- Transaction Sent ---");

        // --- Post-checks ---
        require(deployedAddress != address(0), "Factory returned zero address!");
        console.log("Actual Deployed Wallet Address:", deployedAddress);

        // Verify prediction matches deployment
        require(deployedAddress == predictedAddress, "Error: Deployed address does not match prediction!");
        console.log("Address prediction matched deployment. Success!");

        // Return the address of the newly created wallet proxy
        return deployedAddress;
    }
}
