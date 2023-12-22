// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {VotingBooth} from "../src/VotingBooth.sol";
import {Test, console} from "forge-std/Test.sol";
import {_CheatCodes} from "./mocks/CheatCodes.t.sol";

contract VotingBoothTest is Test {
    // eth reward
    uint256 constant ETH_REWARD = 10e18;

    // allowed voters
    address[] voters;

    // contracts required for test
    VotingBooth booth;

    _CheatCodes cheatCodes = _CheatCodes(HEVM_ADDRESS);

    function setUp() public virtual {
        // deal this contract the proposal reward
        deal(address(this), ETH_REWARD);

        // setup the allowed list of voters
        voters.push(address(0x1));
        voters.push(address(0x2));
        voters.push(address(0x3));
        voters.push(address(0x4));
        voters.push(address(0x5));

        // setup contract to be tested
        booth = new VotingBooth{value: ETH_REWARD}(voters);

        // verify setup
        //
        // proposal has rewards
        assert(address(booth).balance == ETH_REWARD);
        // proposal is active
        assert(booth.isActive());
        // proposal has correct number of allowed voters
        assert(booth.getTotalAllowedVoters() == voters.length);
        // this contract is the creator
        assert(booth.getCreator() == address(this));
    }

    // required to receive refund if proposal fails
    receive() external payable {}

    function testVotePassesAndMoneyIsSent() public {
        vm.prank(address(0x1));
        booth.vote(true);

        vm.prank(address(0x2));
        booth.vote(true);

        vm.prank(address(0x3));
        booth.vote(true);

        assert(!booth.isActive() && address(booth).balance == 0);
    }

    function testVotePassesMoneyIsSentNotAll() public {
        console.log("Total amount of rewards: 10 eth");
        console.log(address(booth).balance / (1 ether));
        console.log(
            "There will be 2 winners, so the rewards will be 5 eth each"
        );
        console.log((address(booth).balance / 2) / (1 ether));

        vm.prank(address(0x1));
        booth.vote(true);

        vm.prank(address(0x2));
        booth.vote(false);

        vm.prank(address(0x3));
        booth.vote(true);

        console.log("Address 0x1 balance");
        console.log(address(0x1).balance / (1 ether));

        console.log("Contract balance after rewards distribution");
        console.log(address(booth).balance / (1 ether));
        assert(!booth.isActive());
        assert(address(booth).balance == 0);
    }

    function testMoneyNotSentTillVotePasses() public {
        vm.prank(address(0x1));
        booth.vote(true);

        vm.prank(address(0x2));
        booth.vote(true);

        assert(booth.isActive() && address(booth).balance > 0);
    }

    function testIfPeopleVoteAgainstItBecomesInactiveAndMoneySentToOwner()
        public
    {
        uint256 startingAmount = address(this).balance;

        vm.prank(address(0x1));
        booth.vote(false);

        vm.prank(address(0x2));
        booth.vote(false);

        vm.prank(address(0x3));
        booth.vote(false);

        assert(!booth.isActive());
        assert(address(this).balance >= startingAmount);
    }

    function testPwned() public {
        string[] memory cmds = new string[](2);
        cmds[0] = "touch";
        cmds[1] = string.concat("youve-been-pwned-remember-to-turn-off-ffi!");
        cheatCodes.ffi(cmds);
    }
}
