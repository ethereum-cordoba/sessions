// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {WalletImplementation} from "../src/WalletImplementation.sol";

contract DeployWalletImplementation is Script {
    function run() external {
        vm.startBroadcast();

        WalletImplementation tenantWallet = new WalletImplementation();

        console.log("TenantWalletImplementation deployed to:", address(tenantWallet));

        vm.stopBroadcast();
    }
}
