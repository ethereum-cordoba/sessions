// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {WalletFactory} from "../src/WalletFactory.sol";
import {console} from "forge-std/console.sol";

contract DeployWalletFactory is Script {
    address private constant WALLET_IMPLEMENTATION = 0x323692519ab774631eeDC1950c9a2b454188073c; // DO NOT hardcode this value, only for demo!

    function run() external returns (address) {
        require(WALLET_IMPLEMENTATION != address(0), "Set WALLET_IMPLEMENTATION address!");

        vm.startBroadcast();
        WalletFactory walletFactory = new WalletFactory(WALLET_IMPLEMENTATION);
        vm.stopBroadcast();

        address factoryAddress = address(walletFactory);
        console.log("WalletFactory Deployed To:", factoryAddress);
        return factoryAddress; // Return the address
    }
}
