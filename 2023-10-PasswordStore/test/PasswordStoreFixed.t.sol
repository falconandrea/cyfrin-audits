// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {PasswordStoreFixed} from "../src/PasswordStoreFixed.sol";
import {DeployPasswordStoreFixed} from "../script/DeployPasswordStoreFixed.s.sol";

contract PasswordStoreFixedTest is Test {
    PasswordStoreFixed public passwordStore;
    DeployPasswordStoreFixed public deployer;
    address public owner;

    function setUp() public {
        deployer = new DeployPasswordStoreFixed();
        passwordStore = deployer.run();
        owner = msg.sender;
    }

    function test_owner_can_set_password() public {
        vm.startPrank(owner);
        string memory expectedPassword = "myNewPassword";
        passwordStore.setPassword(expectedPassword);
        string memory actualPassword = passwordStore.getPassword();
        assertEq(actualPassword, expectedPassword);
    }

    function test_non_owner_reading_password_reverts() public {
        vm.startPrank(address(1));

        vm.expectRevert(PasswordStoreFixed.PasswordStore__NotOwner.selector);
        passwordStore.getPassword();
    }

    /**
     * Test to check that a not-owner user cannot set a password
     */
    function test_not_owner_cannot_set_password() public {
        // User not owner can change the password
        vm.startPrank(address(1));
        string memory expectedPassword = "myNewPassword";

        vm.expectRevert(PasswordStoreFixed.PasswordStore__NotOwner.selector);
        passwordStore.setPassword(expectedPassword);
    }
}
