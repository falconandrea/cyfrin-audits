// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {SantasList} from "../../src/SantasList.sol";
import {SantaToken} from "../../src/SantaToken.sol";
import {Test} from "forge-std/Test.sol";
import {_CheatCodes} from "../mocks/CheatCodes.t.sol";

contract SantasListTest is Test {
    SantasList santasList;
    SantaToken santaToken;

    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    address santa = makeAddr("santa");
    _CheatCodes cheatCodes = _CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        vm.startPrank(santa);
        santasList = new SantasList();
        santaToken = SantaToken(santasList.getSantaToken());
        vm.stopPrank();
    }

    function testCheckList() public {
        vm.prank(santa);
        santasList.checkList(user, SantasList.Status.NICE);
        assertEq(
            uint256(santasList.getNaughtyOrNiceOnce(user)),
            uint256(SantasList.Status.NICE)
        );
    }

    function testCheckListTwice() public {
        vm.startPrank(santa);
        santasList.checkList(user, SantasList.Status.NICE);
        santasList.checkTwice(user, SantasList.Status.NICE);
        vm.stopPrank();

        assertEq(
            uint256(santasList.getNaughtyOrNiceOnce(user)),
            uint256(SantasList.Status.NICE)
        );
        assertEq(
            uint256(santasList.getNaughtyOrNiceTwice(user)),
            uint256(SantasList.Status.NICE)
        );
    }

    function testCantCheckListTwiceWithDifferentThanOnce() public {
        vm.startPrank(santa);
        santasList.checkList(user, SantasList.Status.NICE);
        vm.expectRevert();
        santasList.checkTwice(user, SantasList.Status.NAUGHTY);
        vm.stopPrank();
    }

    function testCantCollectPresentBeforeChristmas() public {
        vm.expectRevert(SantasList.SantasList__NotChristmasYet.selector);
        santasList.collectPresent();
    }

    function testCantCollectPresentIfAlreadyCollected() public {
        vm.startPrank(santa);
        santasList.checkList(user, SantasList.Status.NICE);
        santasList.checkTwice(user, SantasList.Status.NICE);
        vm.stopPrank();

        vm.warp(santasList.CHRISTMAS_2023_BLOCK_TIME() + 1);

        vm.startPrank(user);
        santasList.collectPresent();
        vm.expectRevert(SantasList.SantasList__AlreadyCollected.selector);
        santasList.collectPresent();
    }

    function testCollectPresentNice() public {
        vm.startPrank(santa);
        santasList.checkList(user, SantasList.Status.NICE);
        santasList.checkTwice(user, SantasList.Status.NICE);
        vm.stopPrank();

        vm.warp(santasList.CHRISTMAS_2023_BLOCK_TIME() + 1);

        vm.startPrank(user);
        santasList.collectPresent();
        assertEq(santasList.balanceOf(user), 1);
        vm.stopPrank();
    }

    function testCollectPresentNiceTwice() public {
        vm.startPrank(santa);
        santasList.checkList(user, SantasList.Status.NICE);
        santasList.checkTwice(user, SantasList.Status.NICE);
        vm.stopPrank();

        vm.warp(santasList.CHRISTMAS_2023_BLOCK_TIME() + 1);

        vm.startPrank(user);
        santasList.collectPresent();
        assertEq(santasList.balanceOf(user), 1);

        // User send token to user2 account
        santasList.safeTransferFrom(address(user), address(user2), 0);
        assertEq(santasList.balanceOf(user), 0);

        // User can not collect another present
        santasList.collectPresent();
        assertEq(santasList.balanceOf(user), 1);

        // Move the previous present from original address
        vm.startPrank(user2);
        santasList.safeTransferFrom(address(user2), address(user), 0);

        // Now user have 2 presents
        vm.startPrank(user);
        assertEq(santasList.balanceOf(user), 2);

        vm.stopPrank();
    }

    function testCollectPresentExtraNice() public {
        vm.startPrank(santa);
        santasList.checkList(user, SantasList.Status.EXTRA_NICE);
        santasList.checkTwice(user, SantasList.Status.EXTRA_NICE);
        vm.stopPrank();

        vm.warp(santasList.CHRISTMAS_2023_BLOCK_TIME() + 1);

        vm.startPrank(user);
        santasList.collectPresent();
        assertEq(santasList.balanceOf(user), 1);
        assertEq(santaToken.balanceOf(user), 1e18);
        vm.stopPrank();
    }

    function testCantCollectPresentUnlessAtLeastNice() public {
        vm.startPrank(santa);
        santasList.checkList(user, SantasList.Status.NAUGHTY);
        santasList.checkTwice(user, SantasList.Status.NAUGHTY);
        vm.stopPrank();

        vm.warp(santasList.CHRISTMAS_2023_BLOCK_TIME() + 1);

        vm.startPrank(user);
        vm.expectRevert();
        santasList.collectPresent();
    }

    function testBuyPresentWithTokensOfAnotherUser() public {
        vm.warp(santasList.CHRISTMAS_2023_BLOCK_TIME() + 1);

        // The attacker haven't tokens and nfts
        assertEq(santasList.balanceOf(user), 0);
        assertEq(santaToken.balanceOf(user), 0);

        // User2 is ExtraNice
        vm.startPrank(santa);
        santasList.checkList(user2, SantasList.Status.EXTRA_NICE);
        santasList.checkTwice(user2, SantasList.Status.EXTRA_NICE);
        vm.stopPrank();

        // User2 approve token to spend
        vm.startPrank(user2);
        santaToken.approve(address(santasList), 1e18);
        // User2 collect his present and tokens
        santasList.collectPresent();
        // Check if users2 have 1 nft and tokens
        assertEq(santasList.balanceOf(user2), 1);
        assertEq(santaToken.balanceOf(user2), 1000000000000000000);

        // The attacker buy a nft using user2 tokens
        vm.startPrank(user);
        santasList.buyPresent(user2);

        // Now the attacker have 1 nft and the user2 have 0 tokens
        assertEq(santasList.balanceOf(user), 1);
        assertEq(santaToken.balanceOf(user2), 0);
        vm.stopPrank();
    }

    function testBuyPresent() public {
        vm.startPrank(santa);
        santasList.checkList(user, SantasList.Status.EXTRA_NICE);
        santasList.checkTwice(user, SantasList.Status.EXTRA_NICE);
        vm.stopPrank();

        vm.warp(santasList.CHRISTMAS_2023_BLOCK_TIME() + 1);

        vm.startPrank(user);
        santaToken.approve(address(santasList), 1e18);
        santasList.collectPresent();
        santasList.buyPresent(user);
        assertEq(santasList.balanceOf(user), 2);
        assertEq(santaToken.balanceOf(user), 0);
        vm.stopPrank();
    }

    function testOnlyListCanMintTokens() public {
        vm.expectRevert();
        santaToken.mint(user);
    }

    function testOnlyListCanBurnTokens() public {
        vm.expectRevert();
        santaToken.burn(user);
    }

    function testTokenURI() public {
        string memory tokenURI = santasList.tokenURI(0);
        assertEq(tokenURI, santasList.TOKEN_URI());
    }

    function testGetSantaToken() public {
        assertEq(santasList.getSantaToken(), address(santaToken));
    }

    function testGetSanta() public {
        assertEq(santasList.getSanta(), santa);
    }

    function testPwned() public {
        string[] memory cmds = new string[](2);
        cmds[0] = "touch";
        cmds[1] = string.concat("youve-been-pwned");
        cheatCodes.ffi(cmds);
    }
}
