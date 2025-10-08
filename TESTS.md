# Test tree definitions

Below is the graphical definition of the contract tests implemented on [the test folder](./test)

```
ExecuteSelectorConditionTest
├── When deploying the contract
│   ├── It should set the given DAO address
│   ├── It should correctly initialize allowed selectors from _initialEntries
│   ├── It should succeed with an empty _initialEntries array
│   ├── It should succeed if _initialEntries contains duplicate selectors, ignoring the duplicates
│   └── It should succeed when _initialEntries contains an entry with an empty selectors array
├── When calling isGranted
│   ├── Given the calldata is not for IExecutorexecute
│   │   └── It should return false
│   └── Given the calldata is for IExecutorexecute
│       ├── Given the actions array is empty
│       │   └── It should return true
│       ├── Given an action has calldata length between 1 and 3 bytes
│       │   └── It should return false
│       ├── Given a single action is a function call value  0
│       │   ├── Given the selector is allowed for the target
│       │   │   └── It should return true
│       │   └── Given the selector is not allowed for the target
│       │       └── It should return false
│       ├── Given a single action is a function call with value  0
│       │   ├── Given the selector and native transfers are allowed for the target
│       │   │   └── It should return true
│       │   └── Given the selector is allowed but native transfers are not
│       │       └── It should return false
│       ├── Given a single action is a pure native transfer calldata is empty
│       │   ├── Given value  0 and native transfers are allowed for the target
│       │   │   └── It should return true
│       │   ├── Given value  0 and native transfers are not allowed for the target
│       │   │   └── It should return false
│       │   └── Given value is 0
│       │       └── It should return false
│       └── Given there are multiple actions
│           ├── Given all actions are individually permitted
│           │   └── It should return true
│           └── Given an allowed native transfer is followed by a disallowed function call
│               └── It should correctly return false
├── When calling allowSelectors
│   ├── Given the caller does not have the MANAGESELECTORSPERMISSIONID
│   │   └── It should revert
│   └── Given the caller has the MANAGESELECTORSPERMISSIONID
│       ├── Given the entry contains only new unallowed selectors
│       │   └── It should succeed, update state, and emit a SelectorAllowed event for each selector
│       ├── Given the entry contains only selectors that are already allowed
│       │   └── It should succeed silently without emitting any events or changing state
│       └── Given the entry contains a mix of new and alreadyallowed selectors
│           └── It should succeed and only update state and emit events for the new selectors
├── When calling disallowSelectors
│   ├── Given the caller does not have the MANAGESELECTORSPERMISSIONID 2
│   │   └── It should revert
│   └── Given the caller has the MANAGESELECTORSPERMISSIONID 2
│       ├── Given the entry contains selectors that are currently allowed
│       │   └── It should succeed, update state, and emit a SelectorDisallowed event for each selector
│       ├── Given the entry contains only selectors that are already disallowed
│       │   └── It should succeed silently without emitting any events or changing state
│       └── Given the entry contains a mix of allowed and alreadydisallowed selectors
│           └── It should succeed and only update state and emit events for the selectors that were actually allowed
├── When calling allowNativeTransfers
│   ├── Given the caller does not have the MANAGESELECTORSPERMISSIONID 3
│   │   └── It should revert
│   └── Given the caller has the MANAGESELECTORSPERMISSIONID 3
│       ├── Given Native transfers are not yet allowed for the target address
│       │   └── It should succeed, update state, and emit an NativeTransfersAllowed event
│       └── Given Native transfers are already allowed for the target address
│           └── It should succeed silently without emitting an event or changing state
├── When calling disallowNativeTransfers
│   ├── Given the caller does not have the MANAGESELECTORSPERMISSIONID 4
│   │   └── It should revert
│   └── Given the caller has the MANAGESELECTORSPERMISSIONID 4
│       ├── Given Native transfers are currently allowed for the target address
│       │   └── It should succeed, update state, and emit an NativeTransfersDisallowed event
│       └── Given Native transfers are not currently allowed for the target address
│           └── It should succeed silently without emitting an event or changing state
└── When calling supportsInterface
    ├── It should return true for the IPermissionCondition interface ID
    ├── It should return true for the ERC165 interface ID
    ├── It should return false for a random interface ID
    └── It should return false for the null interface ID (0xffffffff)
```

```
SafeOwnerConditionTest
├── When deploying the contract
│   ├── Given an empty address
│   │   └── It should revert
│   ├── Given a contract that is not a Safe
│   │   └── It should revert
│   ├── It should set the given DAO
│   └── It should define the given safe address
├── When calling isGranted
│   ├── Given the given who is not a Safe member
│   │   └── It should return false
│   └── Given the given who is a Safe member
│       └── It should return true
└── When calling supportsInterface
    ├── It does not support the empty interface
    └── It supports IPermissionCondition
```

```
SelectorConditionTest
├── When deploying the contract
│   ├── It should set the given DAO
│   └── It should define the given selectors as allowed
├── When calling a disallowed function
│   └── It should revert
├── When calling an allowed function
│   └── It should allow execution
├── When calling isGranted
│   ├── Given the calldata references a disallowed selector
│   │   └── It should return false
│   └── Given the calldata references an allowed selector
│       └── It should return true
├── When calling allowSelector
│   ├── Given the caller has no permission
│   │   └── It should revert
│   ├── Given the selector is already allowed
│   │   └── It should revert
│   └── Given the caller has permission
│       ├── It should succeed
│       ├── It should emit an event
│       └── It allowedSelectors should return true
├── When calling removeSelector
│   ├── Given the caller has no permission 2
│   │   └── It should revert
│   ├── Given the selector is not allowed
│   │   └── It should revert
│   └── Given the caller has permission 2
│       ├── It should succeed
│       ├── It should emit an event
│       └── It allowedSelectors should return false
└── When calling supportsInterface
    ├── It does not support the empty interface
    └── It supports IPermissionCondition
```

