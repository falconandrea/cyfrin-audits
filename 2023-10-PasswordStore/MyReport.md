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
