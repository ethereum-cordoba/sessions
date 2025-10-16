// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {SimpleTargetContract} from "../src/SimpleTargetContract.sol";
import {console} from "forge-std/console.sol";

contract DeploySimpleTarget is Script {
    function run() external returns (address) {
        vm.startBroadcast();
        SimpleTargetContract target = new SimpleTargetContract();
        vm.stopBroadcast();
        address targetAddress = address(target);
        console.log("SimpleTargetContract Deployed To:", targetAddress);
        return targetAddress;
    }
}
