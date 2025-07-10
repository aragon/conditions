// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {AragonTest} from "./base/AragonTest.sol";
import {DaoBuilder} from "./helpers/DaoBuilder.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {IExecutor} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {PermissionManager} from "@aragon/osx/core/permission/PermissionManager.sol";
import {DaoUnauthorized} from "@aragon/osx-commons-contracts/src/permission/auth/auth.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import {ExecuteSelectorCondition} from "../src/ExecuteSelectorCondition.sol";
import {ConditionFactory} from "../src/factory/ConditionFactory.sol";
import {
    EXECUTE_PERMISSION_ID,
    SET_METADATA_PERMISSION_ID,
    SET_SIGNATURE_VALIDATOR_PERMISSION_ID,
    REGISTER_STANDARD_CALLBACK_PERMISSION_ID,
    SET_TRUSTED_FORWARDER_PERMISSION_ID,
    MANAGE_SELECTORS_PERMISSION_ID
} from "./constants.sol";

contract ExecuteSelectorConditionTest is AragonTest {
    DaoBuilder builder;
    DAO dao;
    ConditionFactory factory;
    ExecuteSelectorCondition executeSelectorCondition;

    // Events
    event SelectorAllowed(bytes4 selector, address where);
    event SelectorDisallowed(bytes4 selector, address where);
    event NativeTransfersAllowed(address where);
    event NativeTransfersDisallowed(address where);

    bytes4 internal constant DUMMY_SELECTOR_1 = 0x11111111;
    bytes4 internal constant DUMMY_SELECTOR_2 = 0x22222222;

    function setUp() public {
        vm.startPrank(alice);
        builder = new DaoBuilder();
        (dao, factory, executeSelectorCondition,) = builder.build();
    }

    function test_WhenDeployingTheContract() external {
        // It should set the given DAO address
        assertEq(address(executeSelectorCondition.dao()), address(dao));

        // It should succeed with an empty _initialEntries array
        ExecuteSelectorCondition.SelectorTarget[] memory emptyEntries;
        ExecuteSelectorCondition conditionWithEmpty = new ExecuteSelectorCondition(dao, emptyEntries);
        assertEq(address(conditionWithEmpty.dao()), address(dao));

        // It should correctly initialize allowed selectors from _initialEntries
        ExecuteSelectorCondition.SelectorTarget[] memory initialEntries =
            new ExecuteSelectorCondition.SelectorTarget[](2);
        initialEntries[0].where = address(dao);
        initialEntries[0].selectors = new bytes4[](2);
        initialEntries[0].selectors[0] = DUMMY_SELECTOR_1;
        initialEntries[0].selectors[1] = DUMMY_SELECTOR_2;

        initialEntries[1].where = address(this);
        initialEntries[1].selectors = new bytes4[](1);
        initialEntries[1].selectors[0] = DUMMY_SELECTOR_1;

        ExecuteSelectorCondition condition = new ExecuteSelectorCondition(dao, initialEntries);
        assertTrue(condition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
        assertTrue(condition.allowedSelectors(address(dao), DUMMY_SELECTOR_2));
        assertTrue(condition.allowedSelectors(address(this), DUMMY_SELECTOR_1));
        assertFalse(condition.allowedSelectors(address(this), DUMMY_SELECTOR_2));
        assertFalse(condition.allowedSelectors(carol, DUMMY_SELECTOR_1));

        // It should succeed if _initialEntries contains duplicate selectors, ignoring the duplicates
        initialEntries = new ExecuteSelectorCondition.SelectorTarget[](1);
        initialEntries[0].where = address(dao);
        initialEntries[0].selectors = new bytes4[](3);
        initialEntries[0].selectors[0] = DUMMY_SELECTOR_1;
        initialEntries[0].selectors[1] = DUMMY_SELECTOR_2;
        initialEntries[0].selectors[2] = DUMMY_SELECTOR_1; // Duplicate

        condition = new ExecuteSelectorCondition(dao, initialEntries);
        assertTrue(condition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
        assertTrue(condition.allowedSelectors(address(dao), DUMMY_SELECTOR_2));

        // It should succeed when _initialEntries contains an entry with an empty selectors array
        initialEntries = new ExecuteSelectorCondition.SelectorTarget[](1);
        initialEntries[0].where = address(dao);
        initialEntries[0].selectors = new bytes4[](0); // Empty selectors array

        condition = new ExecuteSelectorCondition(dao, initialEntries);
        assertFalse(condition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
    }

    modifier whenCallingIsGranted() {
        _;
    }

    function test_GivenTheCalldataIsNotForIExecutorexecute() external view whenCallingIsGranted {
        // It should return false
        bytes memory calldataNotExecute = abi.encodeCall(DAO.setMetadata, ("metadata"));
        bool isPermitted = executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataNotExecute);
        assertFalse(isPermitted);
    }

    modifier givenTheCalldataIsForIExecutorexecute() {
        _;
    }

    function test_GivenTheActionsArrayIsEmpty()
        external
        view
        whenCallingIsGranted
        givenTheCalldataIsForIExecutorexecute
    {
        // It should return true
        Action[] memory emptyActions;
        bytes memory calldataWithEmptyActions = abi.encodeCall(IExecutor.execute, (bytes32(0), emptyActions, 0));
        bool isPermitted =
            executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataWithEmptyActions);
        assertTrue(isPermitted);
    }

    function test_GivenAnActionHasCalldataLengthBetween1And3Bytes()
        external
        view
        whenCallingIsGranted
        givenTheCalldataIsForIExecutorexecute
    {
        // It should return false
        Action[] memory actions = new Action[](1);
        bytes memory calldataPayload;

        // Length 1
        actions[0].data = hex"aa";
        calldataPayload = abi.encodeCall(IExecutor.execute, (bytes32(0), actions, 0));
        assertFalse(executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataPayload));

        // Length 2
        actions[0].data = hex"aabb";
        calldataPayload = abi.encodeCall(IExecutor.execute, (bytes32(0), actions, 0));
        assertFalse(executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataPayload));

        // Length 3
        actions[0].data = hex"aabbcc";
        calldataPayload = abi.encodeCall(IExecutor.execute, (bytes32(0), actions, 0));
        assertFalse(executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataPayload));
    }

    modifier givenASingleActionIsAFunctionCallValue0() {
        _;
    }

    function test_GivenTheSelectorIsAllowedForTheTarget()
        external
        whenCallingIsGranted
        givenTheCalldataIsForIExecutorexecute
        givenASingleActionIsAFunctionCallValue0
    {
        // It should return true
        dao.grant(address(executeSelectorCondition), alice, MANAGE_SELECTORS_PERMISSION_ID);
        ExecuteSelectorCondition.SelectorTarget memory entry;
        entry.where = address(dao);
        entry.selectors = new bytes4[](1);
        entry.selectors[0] = DAO.setMetadata.selector;
        executeSelectorCondition.allowSelectors(entry);

        Action[] memory actions = new Action[](1);
        actions[0].to = address(dao);
        actions[0].value = 0;
        actions[0].data = abi.encodeCall(DAO.setMetadata, ("new metadata"));

        bytes memory calldataPayload = abi.encodeCall(IExecutor.execute, (bytes32(0), actions, 0));
        assertTrue(executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataPayload));
    }

    function test_GivenTheSelectorIsNotAllowedForTheTarget()
        external
        view
        whenCallingIsGranted
        givenTheCalldataIsForIExecutorexecute
        givenASingleActionIsAFunctionCallValue0
    {
        // It should return false
        Action[] memory actions = new Action[](1);
        actions[0].to = address(dao);
        actions[0].value = 0;
        actions[0].data = abi.encodeCall(DAO.setMetadata, ("new metadata"));

        bytes memory calldataPayload = abi.encodeCall(IExecutor.execute, (bytes32(0), actions, 0));
        assertFalse(executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataPayload));
    }

    modifier givenASingleActionIsAFunctionCallWithValue() {
        _;
    }

    function test_GivenTheSelectorAndNativeTransfersAreAllowedForTheTarget()
        external
        whenCallingIsGranted
        givenTheCalldataIsForIExecutorexecute
        givenASingleActionIsAFunctionCallWithValue
    {
        // It should return true
        dao.grant(address(executeSelectorCondition), alice, MANAGE_SELECTORS_PERMISSION_ID);
        ExecuteSelectorCondition.SelectorTarget memory entry;
        entry.where = address(dao);
        entry.selectors = new bytes4[](1);
        entry.selectors[0] = DAO.setMetadata.selector;
        executeSelectorCondition.allowSelectors(entry);
        executeSelectorCondition.allowNativeTransfers(address(dao));

        Action[] memory actions = new Action[](1);
        actions[0].to = address(dao);
        actions[0].value = 1 ether;
        actions[0].data = abi.encodeCall(DAO.setMetadata, ("new metadata"));

        bytes memory calldataPayload = abi.encodeCall(IExecutor.execute, (bytes32(0), actions, 0));
        assertTrue(executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataPayload));
    }

    function test_GivenTheSelectorIsAllowedButNativeTransfersAreNot()
        external
        whenCallingIsGranted
        givenTheCalldataIsForIExecutorexecute
        givenASingleActionIsAFunctionCallWithValue
    {
        // It should return false
        dao.grant(address(executeSelectorCondition), alice, MANAGE_SELECTORS_PERMISSION_ID);
        ExecuteSelectorCondition.SelectorTarget memory entry;
        entry.where = address(dao);
        entry.selectors = new bytes4[](1);
        entry.selectors[0] = DAO.setMetadata.selector;
        executeSelectorCondition.allowSelectors(entry);
        // Note: Native transfers are not allowed

        Action[] memory actions = new Action[](1);
        actions[0].to = address(dao);
        actions[0].value = 1 ether;
        actions[0].data = abi.encodeCall(DAO.setMetadata, ("new metadata"));

        bytes memory calldataPayload = abi.encodeCall(IExecutor.execute, (bytes32(0), actions, 0));
        assertFalse(executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataPayload));
    }

    modifier givenASingleActionIsAPureNativeTransferCalldataIsEmpty() {
        _;
    }

    function test_GivenValueIsNonZeroAndNativeTransfersAreAllowedForTheTarget()
        external
        whenCallingIsGranted
        givenTheCalldataIsForIExecutorexecute
        givenASingleActionIsAPureNativeTransferCalldataIsEmpty
    {
        // It should return true
        dao.grant(address(executeSelectorCondition), alice, MANAGE_SELECTORS_PERMISSION_ID);
        executeSelectorCondition.allowNativeTransfers(carol);

        Action[] memory actions = new Action[](1);
        actions[0].to = carol;
        actions[0].value = 1 ether;
        actions[0].data = "";

        bytes memory calldataPayload = abi.encodeCall(IExecutor.execute, (bytes32(0), actions, 0));
        assertTrue(executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataPayload));
    }

    function test_GivenValueIsNonZeroAndNativeTransfersAreNotAllowedForTheTarget()
        external
        view
        whenCallingIsGranted
        givenTheCalldataIsForIExecutorexecute
        givenASingleActionIsAPureNativeTransferCalldataIsEmpty
    {
        // It should return false
        Action[] memory actions = new Action[](1);
        actions[0].to = carol;
        actions[0].value = 1 ether;
        actions[0].data = "";

        bytes memory calldataPayload = abi.encodeCall(IExecutor.execute, (bytes32(0), actions, 0));
        assertFalse(executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataPayload));
    }

    function test_GivenValueIs0()
        external
        whenCallingIsGranted
        givenTheCalldataIsForIExecutorexecute
        givenASingleActionIsAPureNativeTransferCalldataIsEmpty
    {
        // It should return false
        dao.grant(address(executeSelectorCondition), alice, MANAGE_SELECTORS_PERMISSION_ID);
        executeSelectorCondition.allowNativeTransfers(carol);

        Action[] memory actions = new Action[](1);
        actions[0].to = carol;
        actions[0].value = 0;
        actions[0].data = "";

        bytes memory calldataPayload = abi.encodeCall(IExecutor.execute, (bytes32(0), actions, 0));
        assertFalse(executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataPayload));
    }

    modifier givenThereAreMultipleActions() {
        _;
    }

    function test_GivenAllActionsAreIndividuallyPermitted()
        external
        whenCallingIsGranted
        givenTheCalldataIsForIExecutorexecute
        givenThereAreMultipleActions
    {
        // It should return true
        dao.grant(address(executeSelectorCondition), alice, MANAGE_SELECTORS_PERMISSION_ID);
        ExecuteSelectorCondition.SelectorTarget memory entry;
        entry.where = address(dao);
        entry.selectors = new bytes4[](1);
        entry.selectors[0] = DAO.setMetadata.selector;
        executeSelectorCondition.allowSelectors(entry);
        executeSelectorCondition.allowNativeTransfers(carol);
        executeSelectorCondition.allowNativeTransfers(address(dao)); // Allow native transfer for action 2

        Action[] memory actions = new Action[](3);
        // Action 0: Function call, no value, allowed selector
        actions[0].to = address(dao);
        actions[0].value = 0;
        actions[0].data = abi.encodeCall(DAO.setMetadata, ("meta"));
        // Action 1: Pure native transfer, allowed
        actions[1].to = carol;
        actions[1].value = 1 ether;
        actions[1].data = "";
        // Action 2: Function call, with value, allowed selector and native transfer
        actions[2].to = address(dao);
        actions[2].value = 0.5 ether;
        actions[2].data = abi.encodeCall(DAO.setMetadata, ("meta2"));

        bytes memory calldataPayload = abi.encodeCall(IExecutor.execute, (bytes32(0), actions, 0));
        assertTrue(executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataPayload));
    }

    function test_GivenAnAllowedNativeTransferIsFollowedByADisallowedFunctionCall()
        external
        whenCallingIsGranted
        givenTheCalldataIsForIExecutorexecute
        givenThereAreMultipleActions
    {
        // It should correctly return false
        dao.grant(address(executeSelectorCondition), alice, MANAGE_SELECTORS_PERMISSION_ID);
        executeSelectorCondition.allowNativeTransfers(carol);
        // Note: DAO.setMetadata.selector is NOT allowed

        Action[] memory actions = new Action[](2);
        // Action 0: Pure native transfer, allowed
        actions[0].to = carol;
        actions[0].value = 1 ether;
        actions[0].data = "";
        // Action 1: Function call, disallowed selector
        actions[1].to = address(dao);
        actions[1].value = 0;
        actions[1].data = abi.encodeCall(DAO.setMetadata, ("meta"));

        bytes memory calldataPayload = abi.encodeCall(IExecutor.execute, (bytes32(0), actions, 0));
        assertFalse(executeSelectorCondition.isGranted(address(0), address(0), bytes32(0), calldataPayload));
    }

    modifier whenCallingAllowSelectors() {
        _;
    }

    function test_RevertGiven_TheCallerDoesNotHaveTheMANAGESELECTORSPERMISSIONID() external whenCallingAllowSelectors {
        // It should revert
        ExecuteSelectorCondition.SelectorTarget memory entry;
        entry.where = address(dao);
        entry.selectors = new bytes4[](1);
        entry.selectors[0] = DUMMY_SELECTOR_1;

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(executeSelectorCondition),
                bob,
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        executeSelectorCondition.allowSelectors(entry);
    }

    modifier givenTheCallerHasTheMANAGESELECTORSPERMISSIONID() {
        vm.startPrank(alice);
        dao.grant(address(executeSelectorCondition), alice, MANAGE_SELECTORS_PERMISSION_ID);
        _;
    }

    function test_GivenTheEntryContainsOnlyNewUnallowedSelectors()
        external
        whenCallingAllowSelectors
        givenTheCallerHasTheMANAGESELECTORSPERMISSIONID
    {
        // It should succeed, update state, and emit a SelectorAllowed event for each selector
        assertFalse(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
        assertFalse(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_2));

        ExecuteSelectorCondition.SelectorTarget memory entry;
        entry.where = address(dao);
        entry.selectors = new bytes4[](2);
        entry.selectors[0] = DUMMY_SELECTOR_1;
        entry.selectors[1] = DUMMY_SELECTOR_2;

        vm.expectEmit(true, true, true, true);
        emit SelectorAllowed(DUMMY_SELECTOR_1, address(dao));
        vm.expectEmit(true, true, true, true);
        emit SelectorAllowed(DUMMY_SELECTOR_2, address(dao));
        executeSelectorCondition.allowSelectors(entry);

        assertTrue(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
        assertTrue(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_2));
    }

    function test_GivenTheEntryContainsOnlySelectorsThatAreAlreadyAllowed()
        external
        whenCallingAllowSelectors
        givenTheCallerHasTheMANAGESELECTORSPERMISSIONID
    {
        // It should succeed silently without emitting any events or changing state
        ExecuteSelectorCondition.SelectorTarget memory entry;
        entry.where = address(dao);
        entry.selectors = new bytes4[](1);
        entry.selectors[0] = DUMMY_SELECTOR_1;
        executeSelectorCondition.allowSelectors(entry); // First time allowance
        assertTrue(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));

        executeSelectorCondition.allowSelectors(entry); // Second time
        assertTrue(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
    }

    function test_GivenTheEntryContainsAMixOfNewAndAlreadyallowedSelectors()
        external
        whenCallingAllowSelectors
        givenTheCallerHasTheMANAGESELECTORSPERMISSIONID
    {
        // It should succeed and only update state and emit events for the new selectors
        ExecuteSelectorCondition.SelectorTarget memory initialEntry;
        initialEntry.where = address(dao);
        initialEntry.selectors = new bytes4[](1);
        initialEntry.selectors[0] = DUMMY_SELECTOR_1;
        executeSelectorCondition.allowSelectors(initialEntry); // Allow selector 1
        assertTrue(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
        assertFalse(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_2));

        ExecuteSelectorCondition.SelectorTarget memory mixedEntry;
        mixedEntry.where = address(dao);
        mixedEntry.selectors = new bytes4[](2);
        mixedEntry.selectors[0] = DUMMY_SELECTOR_1; // Already allowed
        mixedEntry.selectors[1] = DUMMY_SELECTOR_2; // New

        vm.expectEmit(true, true, true, true); // Only one event for the new selector
        emit SelectorAllowed(DUMMY_SELECTOR_2, address(dao));
        executeSelectorCondition.allowSelectors(mixedEntry);

        assertTrue(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
        assertTrue(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_2));
    }

    modifier whenCallingDisallowSelectors() {
        _;
    }

    function test_RevertGiven_TheCallerDoesNotHaveTheMANAGESELECTORSPERMISSIONID2()
        external
        whenCallingDisallowSelectors
    {
        // It should revert
        ExecuteSelectorCondition.SelectorTarget memory entry;
        entry.where = address(dao);
        entry.selectors = new bytes4[](1);
        entry.selectors[0] = DUMMY_SELECTOR_1;

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(executeSelectorCondition),
                bob,
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        executeSelectorCondition.disallowSelectors(entry);
    }

    modifier givenTheCallerHasTheMANAGESELECTORSPERMISSIONID2() {
        vm.startPrank(alice);
        dao.grant(address(executeSelectorCondition), alice, MANAGE_SELECTORS_PERMISSION_ID);
        _;
    }

    function test_GivenTheEntryContainsSelectorsThatAreCurrentlyAllowed()
        external
        whenCallingDisallowSelectors
        givenTheCallerHasTheMANAGESELECTORSPERMISSIONID2
    {
        // It should succeed, update state, and emit a SelectorDisallowed event for each selector
        ExecuteSelectorCondition.SelectorTarget memory entry;
        entry.where = address(dao);
        entry.selectors = new bytes4[](1);
        entry.selectors[0] = DUMMY_SELECTOR_1;
        executeSelectorCondition.allowSelectors(entry);
        assertTrue(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));

        vm.expectEmit(true, true, true, true);
        emit SelectorDisallowed(DUMMY_SELECTOR_1, address(dao));
        executeSelectorCondition.disallowSelectors(entry);
        assertFalse(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
    }

    function test_GivenTheEntryContainsOnlySelectorsThatAreAlreadyDisallowed()
        external
        whenCallingDisallowSelectors
        givenTheCallerHasTheMANAGESELECTORSPERMISSIONID2
    {
        // It should succeed silently without emitting any events or changing state
        assertFalse(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
        ExecuteSelectorCondition.SelectorTarget memory entry;
        entry.where = address(dao);
        entry.selectors = new bytes4[](1);
        entry.selectors[0] = DUMMY_SELECTOR_1;

        executeSelectorCondition.disallowSelectors(entry);
        assertFalse(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
    }

    function test_GivenTheEntryContainsAMixOfAllowedAndAlreadydisallowedSelectors()
        external
        whenCallingDisallowSelectors
        givenTheCallerHasTheMANAGESELECTORSPERMISSIONID2
    {
        // It should succeed and only update state and emit events for the selectors that were actually allowed
        ExecuteSelectorCondition.SelectorTarget memory entry;
        entry.where = address(dao);
        entry.selectors = new bytes4[](1);
        entry.selectors[0] = DUMMY_SELECTOR_1;
        executeSelectorCondition.allowSelectors(entry); // Allow selector 1
        assertTrue(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
        assertFalse(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_2));

        ExecuteSelectorCondition.SelectorTarget memory mixedEntry;
        mixedEntry.where = address(dao);
        mixedEntry.selectors = new bytes4[](2);
        mixedEntry.selectors[0] = DUMMY_SELECTOR_1; // Allowed
        mixedEntry.selectors[1] = DUMMY_SELECTOR_2; // Already disallowed

        vm.expectEmit(true, true, true, true);
        emit SelectorDisallowed(DUMMY_SELECTOR_1, address(dao));
        executeSelectorCondition.disallowSelectors(mixedEntry);
        assertFalse(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_1));
        assertFalse(executeSelectorCondition.allowedSelectors(address(dao), DUMMY_SELECTOR_2));
    }

    modifier whenCallingAllowNativeTransfers() {
        _;
    }

    function test_RevertGiven_TheCallerDoesNotHaveTheMANAGESELECTORSPERMISSIONID3()
        external
        whenCallingAllowNativeTransfers
    {
        // It should revert
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(executeSelectorCondition),
                bob,
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        executeSelectorCondition.allowNativeTransfers(carol);
    }

    modifier givenTheCallerHasTheMANAGESELECTORSPERMISSIONID3() {
        vm.startPrank(alice);
        dao.grant(address(executeSelectorCondition), alice, MANAGE_SELECTORS_PERMISSION_ID);
        _;
    }

    function test_GivenNativeTransfersAreNotYetAllowedForTheTargetAddress()
        external
        whenCallingAllowNativeTransfers
        givenTheCallerHasTheMANAGESELECTORSPERMISSIONID3
    {
        // It should succeed, update state, and emit an NativeTransfersAllowed event
        assertFalse(executeSelectorCondition.allowedNativeTransfers(carol));

        vm.expectEmit(true, true, true, true);
        emit NativeTransfersAllowed(carol);
        executeSelectorCondition.allowNativeTransfers(carol);

        assertTrue(executeSelectorCondition.allowedNativeTransfers(carol));
    }

    function test_GivenNativeTransfersAreAlreadyAllowedForTheTargetAddress()
        external
        whenCallingAllowNativeTransfers
        givenTheCallerHasTheMANAGESELECTORSPERMISSIONID3
    {
        // It should succeed silently without emitting an event or changing state
        executeSelectorCondition.allowNativeTransfers(carol); // Allow first time
        assertTrue(executeSelectorCondition.allowedNativeTransfers(carol));

        executeSelectorCondition.allowNativeTransfers(carol); // Allow second time
        assertTrue(executeSelectorCondition.allowedNativeTransfers(carol));
    }

    modifier whenCallingDisallowNativeTransfers() {
        _;
    }

    function test_RevertGiven_TheCallerDoesNotHaveTheMANAGESELECTORSPERMISSIONID4()
        external
        whenCallingDisallowNativeTransfers
    {
        // It should revert
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(executeSelectorCondition),
                bob,
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        executeSelectorCondition.disallowNativeTransfers(carol);
    }

    modifier givenTheCallerHasTheMANAGESELECTORSPERMISSIONID4() {
        vm.startPrank(alice);
        dao.grant(address(executeSelectorCondition), alice, MANAGE_SELECTORS_PERMISSION_ID);
        _;
    }

    function test_GivenNativeTransfersAreCurrentlyAllowedForTheTargetAddress()
        external
        whenCallingDisallowNativeTransfers
        givenTheCallerHasTheMANAGESELECTORSPERMISSIONID4
    {
        // It should succeed, update state, and emit an NativeTransfersDisallowed event
        executeSelectorCondition.allowNativeTransfers(carol);
        assertTrue(executeSelectorCondition.allowedNativeTransfers(carol));

        vm.expectEmit(true, true, true, true);
        emit NativeTransfersDisallowed(carol);
        executeSelectorCondition.disallowNativeTransfers(carol);

        assertFalse(executeSelectorCondition.allowedNativeTransfers(carol));
    }

    function test_GivenNativeTransfersAreNotCurrentlyAllowedForTheTargetAddress()
        external
        whenCallingDisallowNativeTransfers
        givenTheCallerHasTheMANAGESELECTORSPERMISSIONID4
    {
        // It should succeed silently without emitting an event or changing state
        assertFalse(executeSelectorCondition.allowedNativeTransfers(carol));

        executeSelectorCondition.disallowNativeTransfers(carol);
        assertFalse(executeSelectorCondition.allowedNativeTransfers(carol));
    }

    function test_WhenCallingSupportsInterface() external view {
        // It should return true for the IPermissionCondition interface ID
        assertTrue(executeSelectorCondition.supportsInterface(type(IPermissionCondition).interfaceId));
        // It should return true for the ERC165 interface ID
        assertTrue(executeSelectorCondition.supportsInterface(type(IERC165Upgradeable).interfaceId));
        // It should return false for a random interface ID
        assertFalse(executeSelectorCondition.supportsInterface(0x12345678));
        // It should return false for the null interface ID (0xffffffff)
        assertFalse(executeSelectorCondition.supportsInterface(0xffffffff));
    }
}
