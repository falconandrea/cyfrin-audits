// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";
import {Attacker} from "../src/Attacker.sol";

contract ReEntrancyTest is Test {
    PuppyRaffle puppyRaffle;
    Attacker attacker;
    uint256 entranceFee = 1e18;
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
        attacker = new Attacker(address(puppyRaffle));
        vm.deal(address(puppyRaffle), 5 ether);
        vm.deal(address(attacker), 2 ether);
    }

    function testReentrancy() public {
        attacker.Attack();
        console.log("Final amount attacker", address(attacker).balance);
        console.log("Final amount contract", address(puppyRaffle).balance);
    }
}
