// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Script, console2} from "forge-std/Script.sol";
import {PasswordStoreFixed} from "../src/PasswordStoreFixed.sol";

contract DeployPasswordStoreFixed is Script {
    function run() public returns (PasswordStoreFixed) {
        vm.startBroadcast();
        PasswordStoreFixed passwordStore = new PasswordStoreFixed();
        passwordStore.setPassword("myPassword");
        vm.stopBroadcast();
        return passwordStore;
    }
}
