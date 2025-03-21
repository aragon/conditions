# Test tree definitions

Below is the graphical definition of the contract tests implemented on [the test folder](./test)

```
ExecuteSelectorConditionTest
├── When deploying the contract
│   ├── It should set the given DAO
│   └── It should define the given selectors as allowed
├── When not calling execute
│   └── It should revert
├── When calling execute
│   ├── Given not all actions are allowed
│   │   └── It should revert
│   ├── Given not all targets are allowed
│   │   └── It should revert
│   └── Given all actions are allowed
│       └── It should allow execution
├── When calling isGranted
│   ├── Given not all actions are allowed 2
│   │   └── It should return false
│   ├── Given not all targets are allowed 2
│   │   └── It return false
│   └── Given all actions are allowed 2
│       └── It should return true
├── When calling addSelector
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
├── When calling addSelector
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

