## s_owner is not set as immutable consuming more gas

### Severity

Low risk

### Relevant GitHub Links

[https://github.com/Cyfrin/2023-10-PasswordStore/blob/856ed94bfcf1031bf9d13514cb21b591d88ed323/src/PasswordStore.sol#L13](https://github.com/Cyfrin/2023-10-PasswordStore/blob/856ed94bfcf1031bf9d13514cb21b591d88ed323/src/PasswordStore.sol#L13)

[https://github.com/Cyfrin/2023-10-PasswordStore/blob/856ed94bfcf1031bf9d13514cb21b591d88ed323/src/PasswordStore.sol#L19](https://github.com/Cyfrin/2023-10-PasswordStore/blob/856ed94bfcf1031bf9d13514cb21b591d88ed323/src/PasswordStore.sol#L19)

## Summary

The `PasswordStore::s_owner` variable is not changed after the initialization inside the constructor, so it is best to set it as immutable to save gas.

## Vulnerability Details

```solidity
contract PasswordStore {
    error PasswordStore__NotOwner();

@>  address private s_owner;
    string private s_password;
```

If a variable is not changed during the life of the smart contract it is better to set it as immutable because reading it costs much less gas.

## Impact

More gas is wasted.

Using the command `forge test --gas-report`, the deployment gas cost results of 225780 without immutable, and 209477 with immutable.
Also the `getPassword` function consumes max 3320 of gas without immutable, and 1217 with immutable.

## Tools Used

- manual check
- foundry

## Recommendations

Set `s_owner` to immutable.

```diff
-  address private s_owner;
+  address private immutable s_owner;
```

---

## a not-owner user can change the password

### Severity

High risk

### Relevant GitHub Links

[https://github.com/Cyfrin/2023-10-PasswordStore/blob/856ed94bfcf1031bf9d13514cb21b591d88ed323/src/PasswordStore.sol#L26-L27](https://github.com/Cyfrin/2023-10-PasswordStore/blob/856ed94bfcf1031bf9d13514cb21b591d88ed323/src/PasswordStore.sol#L26-L27)

## Summary

A not-owner user can change the password. The `PasswordStore::setPassword` function should only be usable by the owner of the smart contract.

## Vulnerability Details

The `PasswordStore::setPassword` function does not check whether the user who is calling the function is the owner of the contract or not. This means that any user who calls the function can change the password.

```solidity
    function setPassword(string memory newPassword) external {
@>      s_password = newPassword;
        emit SetNetPassword();
    }
```

Through this test you can verify that a not-owner user is able to change the password.

```solidity
function test_not_owner_can_set_password() public {
    // User not owner can change the password
    vm.startPrank(address(1));
    string memory expectedPassword = "myNewPassword";
    passwordStore.setPassword(expectedPassword);

    // Check if password is changed
    vm.startPrank(owner);
    string memory actualPassword = passwordStore.getPassword();
    assertEq(actualPassword, expectedPassword);
}
```

## Impact

The impact is high because the function was designed to be used only by the owner, therefore this vulnerability causes a high damage to the smart contract because the operation is not as desired.

## Tools Used

- manual review
- foundry

## Recommendations

To avoid this vulnerability you need to create a modifier that is called on the function `PasswordStore::setPassword`. This modifier verifies that the user who is calling the function, via the value of `msg.sender`, is equal to the value saved inside s_owner.

```diff
+    modifier isOwner() {
+        _checkOwner();
+        _;
+    }

+    function _checkOwner() internal view {
+        if (msg.sender != s_owner) {
+            revert PasswordStore__NotOwner();
+        }
+    }

-    function setPassword(string memory newPassword) external {
+    function setPassword(string memory newPassword) external isOwner {
     s_password = newPassword;
          emit SetNetPassword();
     }

-    function getPassword() external view returns (string memory) {
+    function getPassword() external view isOwner returns (string memory) {
-        if (msg.sender != s_owner) {
-            revert PasswordStore__NotOwner();
-        }
         return s_password;
     }
```

---

## using the modifier also in the getPassword function saves gas

### Severity

Low risk

### Relevant GitHub Links

[https://github.com/Cyfrin/2023-10-PasswordStore/blob/856ed94bfcf1031bf9d13514cb21b591d88ed323/src/PasswordStore.sol#L35](https://github.com/Cyfrin/2023-10-PasswordStore/blob/856ed94bfcf1031bf9d13514cb21b591d88ed323/src/PasswordStore.sol#L35)

## Summary

Using the `PasswordStore::isOwner` modifier, created in the previous submission, we can save gas on the function calls.

## Vulnerability Details

Replacing the `if` inside the `PasswordStore::getPassword` function with the modifier `isOwner` we can save gas in the function call.

```solidity
@>  function getPassword() external view returns (string memory) {
@>      if (msg.sender != s_owner) {
@>        revert PasswordStore__NotOwner();
@>      }
        return s_password;
    }
```

## Impact

If we use the modifier also in the `PasswordStore::getPassword` function, as well as in the `PasswordStore::setPassword` function, the average gas consumption of a `PasswordStore::getPassword` call goes from 2990 to 1842, the maximum consumption goes from 3320 to 2343.
It also reduces the amount of duplicate code inside the smart contract.

## Tools Used

- manual review
- foundry

## Recommendations

As shown previously, we have to create an internal function `_checkOwner` with the `if` to check if the caller user is the owner, create the modifier `isOwner` that uses the function created, and remove the if from the `PasswordStore::getPassword` function and add the modifier `isOwner` in the definition of the `PasswordStore::getPassword` function.

```diff
+    modifier isOwner() {
+        _checkOwner();
+        _;
+    }

+    function _checkOwner() internal view {
+        if (msg.sender != s_owner) {
+            revert PasswordStore__NotOwner();
+        }
+    }

-    function getPassword() external view returns (string memory) {
+    function getPassword() external view isOwner returns (string memory) {
-        if (msg.sender != s_owner) {
-            revert PasswordStore__NotOwner();
-        }
         return s_password;
     }
```
