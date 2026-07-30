// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {AragonTest} from "./base/AragonTest.sol";
import {DaoBuilder} from "./helpers/DaoBuilder.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {IExecutor} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {DaoUnauthorized} from "@aragon/osx-commons-contracts/src/permission/auth/auth.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ExecuteSelectorCrossChainCondition, ICrossChainController} from "../src/ExecuteSelectorCrossChainCondition.sol";
import {MANAGE_SELECTORS_PERMISSION_ID} from "./constants.sol";

/// @notice An arbitrary contract living on the destination chain, called through the bridge
interface IRemoteContract {
    function doSomething(address _who, uint256 _amount) external;

    function doSomethingElse(uint256 _amount) external;
}

/// @notice Minimal CrossChainController that advertises ICrossChainController via ERC-165
contract MockCrossChainController is ERC165, ICrossChainController {
    function supportsInterface(bytes4 _interfaceId) public view override returns (bool) {
        return _interfaceId == type(ICrossChainController).interfaceId || super.supportsInterface(_interfaceId);
    }

    function forwardMessage(uint256, uint256, bytes memory) external pure returns (bytes32) {
        return bytes32(0);
    }

    function receiveMessage(uint256, bytes memory, uint256) external pure returns (bytes32) {
        return bytes32(0);
    }

    function retryMessage(bytes memory) external pure {}
}

contract ExecuteSelectorCrossChainConditionTest is AragonTest {
    DaoBuilder builder;
    DAO dao;
    ExecuteSelectorCrossChainCondition condition;
    MockCrossChainController ccc;

    // Events (must mirror the contract)
    event SelectorAllowed(uint256 chainId, bytes4 selector, address where);
    event SelectorDisallowed(uint256 chainId, bytes4 selector, address where);
    event NativeTransfersAllowed(uint256 chainId, address where);
    event NativeTransfersDisallowed(uint256 chainId, address where);

    bytes4 internal constant DUMMY_SELECTOR_1 = 0x11111111;
    bytes4 internal constant DUMMY_SELECTOR_2 = 0x22222222;
    bytes4 internal constant FORWARD_MESSAGE_SELECTOR = ICrossChainController.forwardMessage.selector;

    bytes4 internal constant REMOTE_SELECTOR = IRemoteContract.doSomething.selector;
    bytes4 internal constant OTHER_REMOTE_SELECTOR = IRemoteContract.doSomethingElse.selector;

    uint256 internal constant DST_CHAIN_ID = 137; // arbitrary destination chain
    uint256 internal constant OTHER_CHAIN_ID = 42161; // a different destination chain
    uint256 internal constant GAS_LIMIT = 500_000;

    address internal remoteTarget = address(0x1234);
    /// @dev A contract on the destination chain; it does not exist on this chain
    address internal remoteContract = address(0xDEAD);

    function setUp() public {
        builder = new DaoBuilder();
        (dao,,,) = builder.build();

        ExecuteSelectorCrossChainCondition.SelectorTarget[] memory emptyEntries;
        condition = new ExecuteSelectorCrossChainCondition(IDAO(address(dao)), emptyEntries);
        ccc = new MockCrossChainController();

        // The test contract manages the allowlists directly
        vm.prank(alice);
        dao.grant(address(condition), address(this), MANAGE_SELECTORS_PERMISSION_ID);

        vm.label(address(condition), "ExecuteSelectorCrossChainCondition");
        vm.label(address(ccc), "CrossChainController");
    }

    // Helpers

    function _entry(address _where, bytes4 _selector)
        internal
        pure
        returns (ExecuteSelectorCrossChainCondition.SelectorTarget memory entry)
    {
        entry.where = _where;
        entry.selectors = new bytes4[](1);
        entry.selectors[0] = _selector;
    }

    function _grantManageSelectors() internal {
        dao.grant(address(condition), alice, MANAGE_SELECTORS_PERMISSION_ID);
    }

    /// @dev Encodes an outer cross-chain action targeting the CCC, wrapping the given inner actions
    function _crossChainAction(uint256 _dstChainId, Action[] memory _innerActions)
        internal
        view
        returns (Action memory action)
    {
        action.to = address(ccc);
        action.value = 0;
        action.data =
            abi.encodeCall(ICrossChainController.forwardMessage, (_dstChainId, GAS_LIMIT, abi.encode(_innerActions)));
    }

    /// @dev A single inner action calling the remote contract on the destination chain
    function _remoteCall(uint256 _value) internal view returns (Action[] memory innerActions) {
        innerActions = new Action[](1);
        innerActions[0].to = remoteContract;
        innerActions[0].value = _value;
        innerActions[0].data = abi.encodeCall(IRemoteContract.doSomething, (carol, 1000));
    }

    function _executeCalldata(Action[] memory _actions) internal pure returns (bytes memory) {
        return abi.encodeCall(IExecutor.execute, (bytes32(0), _actions, 0));
    }

    function _isGranted(bytes memory _calldata) internal view returns (bool) {
        return condition.isGranted(address(0), address(0), bytes32(0), _calldata);
    }

    // Deployment

    function test_WhenDeployingTheContract() external {
        // It should set the given DAO address
        assertEq(address(condition.dao()), address(dao));

        // It should register the initial entries under the current chain id
        ExecuteSelectorCrossChainCondition.SelectorTarget[] memory initialEntries =
            new ExecuteSelectorCrossChainCondition.SelectorTarget[](2);
        initialEntries[0].where = address(dao);
        initialEntries[0].selectors = new bytes4[](2);
        initialEntries[0].selectors[0] = DUMMY_SELECTOR_1;
        initialEntries[0].selectors[1] = DUMMY_SELECTOR_2;
        initialEntries[1].where = address(this);
        initialEntries[1].selectors = new bytes4[](1);
        initialEntries[1].selectors[0] = DUMMY_SELECTOR_1;

        ExecuteSelectorCrossChainCondition newCondition =
            new ExecuteSelectorCrossChainCondition(IDAO(address(dao)), initialEntries);

        assertTrue(newCondition.allowedSelectors(block.chainid, address(dao), DUMMY_SELECTOR_1));
        assertTrue(newCondition.allowedSelectors(block.chainid, address(dao), DUMMY_SELECTOR_2));
        assertTrue(newCondition.allowedSelectors(block.chainid, address(this), DUMMY_SELECTOR_1));
        assertFalse(newCondition.allowedSelectors(block.chainid, address(this), DUMMY_SELECTOR_2));

        // It should not register anything under other chain ids
        assertFalse(newCondition.allowedSelectors(DST_CHAIN_ID, address(dao), DUMMY_SELECTOR_1));
    }

    // allowSelectors / disallowSelectors

    modifier whenCallingAllowSelectors() {
        _;
    }

    function test_RevertGiven_TheCallerDoesNotHaveTheManageSelectorsPermission() external whenCallingAllowSelectors {
        // It should revert on every permissioned function (both overloads of each)
        bytes memory unauthorizedError = abi.encodeWithSelector(
            DaoUnauthorized.selector, address(dao), address(condition), bob, MANAGE_SELECTORS_PERMISSION_ID
        );

        vm.startPrank(bob);

        // allowSelectors
        vm.expectRevert(unauthorizedError);
        condition.allowSelectors(_entry(address(dao), DUMMY_SELECTOR_1));

        vm.expectRevert(unauthorizedError);
        condition.allowSelectors(DST_CHAIN_ID, _entry(address(dao), DUMMY_SELECTOR_1));

        // disallowSelectors
        vm.expectRevert(unauthorizedError);
        condition.disallowSelectors(_entry(address(dao), DUMMY_SELECTOR_1));

        vm.expectRevert(unauthorizedError);
        condition.disallowSelectors(DST_CHAIN_ID, _entry(address(dao), DUMMY_SELECTOR_1));

        // allowNativeTransfers
        vm.expectRevert(unauthorizedError);
        condition.allowNativeTransfers(remoteTarget);

        vm.expectRevert(unauthorizedError);
        condition.allowNativeTransfers(DST_CHAIN_ID, remoteTarget);

        // disallowNativeTransfers
        vm.expectRevert(unauthorizedError);
        condition.disallowNativeTransfers(remoteTarget);

        vm.expectRevert(unauthorizedError);
        condition.disallowNativeTransfers(DST_CHAIN_ID, remoteTarget);

        vm.stopPrank();
    }

    function test_GivenAChainIdIsPassed() external whenCallingAllowSelectors {
        vm.expectEmit(true, true, true, true);
        emit SelectorAllowed(DST_CHAIN_ID, DUMMY_SELECTOR_1, remoteTarget);
        condition.allowSelectors(DST_CHAIN_ID, _entry(remoteTarget, DUMMY_SELECTOR_1));

        assertTrue(condition.allowedSelectors(DST_CHAIN_ID, remoteTarget, DUMMY_SELECTOR_1));
        // It should not affect the same target on other chains
        assertFalse(condition.allowedSelectors(block.chainid, remoteTarget, DUMMY_SELECTOR_1));
    }

    function test_GivenNoChainIdIsPassed() external whenCallingAllowSelectors {
        vm.expectEmit(true, true, true, true);
        emit SelectorAllowed(block.chainid, DUMMY_SELECTOR_1, address(dao));
        condition.allowSelectors(_entry(address(dao), DUMMY_SELECTOR_1));

        assertTrue(condition.allowedSelectors(block.chainid, address(dao), DUMMY_SELECTOR_1));
        assertFalse(condition.allowedSelectors(DST_CHAIN_ID, address(dao), DUMMY_SELECTOR_1));
    }

    function test_WhenCallingDisallowSelectors() external {
        condition.allowSelectors(DST_CHAIN_ID, _entry(remoteTarget, DUMMY_SELECTOR_1));
        condition.allowSelectors(_entry(remoteTarget, DUMMY_SELECTOR_1));

        vm.expectEmit(true, true, true, true);
        emit SelectorDisallowed(DST_CHAIN_ID, DUMMY_SELECTOR_1, remoteTarget);
        condition.disallowSelectors(DST_CHAIN_ID, _entry(remoteTarget, DUMMY_SELECTOR_1));

        assertFalse(condition.allowedSelectors(DST_CHAIN_ID, remoteTarget, DUMMY_SELECTOR_1));
        // The current-chain entry stays untouched
        assertTrue(condition.allowedSelectors(block.chainid, remoteTarget, DUMMY_SELECTOR_1));

        // The no-chainId overload clears the current chain
        vm.expectEmit(true, true, true, true);
        emit SelectorDisallowed(block.chainid, DUMMY_SELECTOR_1, remoteTarget);
        condition.disallowSelectors(_entry(remoteTarget, DUMMY_SELECTOR_1));
        assertFalse(condition.allowedSelectors(block.chainid, remoteTarget, DUMMY_SELECTOR_1));
    }

    // allowNativeTransfers / disallowNativeTransfers

    function test_WhenCallingAllowNativeTransfers() external {
        vm.expectEmit(true, true, true, true);
        emit NativeTransfersAllowed(DST_CHAIN_ID, remoteTarget);
        condition.allowNativeTransfers(DST_CHAIN_ID, remoteTarget);

        assertTrue(condition.allowedNativeTransfers(DST_CHAIN_ID, remoteTarget));
        assertFalse(condition.allowedNativeTransfers(block.chainid, remoteTarget));

        // The no-chainId overload defaults to the current chain
        vm.expectEmit(true, true, true, true);
        emit NativeTransfersAllowed(block.chainid, carol);
        condition.allowNativeTransfers(carol);
        assertTrue(condition.allowedNativeTransfers(block.chainid, carol));

        // Allowing twice is a silent no-op
        condition.allowNativeTransfers(DST_CHAIN_ID, remoteTarget);
        assertTrue(condition.allowedNativeTransfers(DST_CHAIN_ID, remoteTarget));
    }

    function test_WhenCallingDisallowNativeTransfers() external {
        condition.allowNativeTransfers(DST_CHAIN_ID, remoteTarget);
        condition.allowNativeTransfers(remoteTarget);

        // It should clear the flag on the given chain only and emit the event
        vm.expectEmit(true, true, true, true);
        emit NativeTransfersDisallowed(DST_CHAIN_ID, remoteTarget);
        condition.disallowNativeTransfers(DST_CHAIN_ID, remoteTarget);

        assertFalse(condition.allowedNativeTransfers(DST_CHAIN_ID, remoteTarget));
        assertTrue(condition.allowedNativeTransfers(block.chainid, remoteTarget));

        // The no-chainId overload clears the current chain
        condition.disallowNativeTransfers(remoteTarget);
        assertFalse(condition.allowedNativeTransfers(block.chainid, remoteTarget));
    }

    // Passing block.chainid explicitly

    function test_GivenTheCurrentChainIdIsPassedExplicitly() external {
        // It should be equivalent to using the overload without a chain id

        // Allowing with an explicit block.chainid is visible to the no-chainId path
        condition.allowSelectors(block.chainid, _entry(remoteTarget, DUMMY_SELECTOR_1));
        assertTrue(condition.allowedSelectors(block.chainid, remoteTarget, DUMMY_SELECTOR_1));

        // Disallowing without a chain id clears what the explicit call had set
        vm.expectEmit(true, true, true, true);
        emit SelectorDisallowed(block.chainid, DUMMY_SELECTOR_1, remoteTarget);
        condition.disallowSelectors(_entry(remoteTarget, DUMMY_SELECTOR_1));
        assertFalse(condition.allowedSelectors(block.chainid, remoteTarget, DUMMY_SELECTOR_1));

        // And the reverse: allow without a chain id, disallow with an explicit block.chainid
        condition.allowSelectors(_entry(remoteTarget, DUMMY_SELECTOR_2));
        assertTrue(condition.allowedSelectors(block.chainid, remoteTarget, DUMMY_SELECTOR_2));

        vm.expectEmit(true, true, true, true);
        emit SelectorDisallowed(block.chainid, DUMMY_SELECTOR_2, remoteTarget);
        condition.disallowSelectors(block.chainid, _entry(remoteTarget, DUMMY_SELECTOR_2));
        assertFalse(condition.allowedSelectors(block.chainid, remoteTarget, DUMMY_SELECTOR_2));

        // The same holds for native transfers
        condition.allowNativeTransfers(block.chainid, carol);
        assertTrue(condition.allowedNativeTransfers(block.chainid, carol));

        vm.expectEmit(true, true, true, true);
        emit NativeTransfersDisallowed(block.chainid, carol);
        condition.disallowNativeTransfers(carol);
        assertFalse(condition.allowedNativeTransfers(block.chainid, carol));
    }

    // isGranted: generic

    modifier whenCallingIsGranted() {
        _;
    }

    function test_GivenTheCalldataIsNotForExecute() external view whenCallingIsGranted {
        // It should return false
        bytes memory calldataNotExecute = abi.encodeCall(DAO.setMetadata, ("metadata"));
        assertFalse(_isGranted(calldataNotExecute));
    }

    function test_GivenTheActionsArrayIsEmpty() external view whenCallingIsGranted {
        // It should return true
        Action[] memory emptyActions;
        assertTrue(_isGranted(_executeCalldata(emptyActions)));
    }

    // isGranted: local (same chain) actions

    modifier givenALocalAction() {
        _;
    }

    function test_GivenTheLocalSelectorIsAllowed() external whenCallingIsGranted givenALocalAction {
        condition.allowSelectors(_entry(address(dao), DAO.setMetadata.selector));

        Action[] memory actions = new Action[](1);
        actions[0].to = address(dao);
        actions[0].data = abi.encodeCall(DAO.setMetadata, ("meta"));

        assertTrue(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenTheLocalSelectorIsNotAllowed() external view whenCallingIsGranted givenALocalAction {
        // It should return false
        Action[] memory actions = new Action[](1);
        actions[0].to = address(dao);
        actions[0].data = abi.encodeCall(DAO.setMetadata, ("meta"));

        assertFalse(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenTheLocalSelectorIsOnlyAllowedOnAnotherChain() external whenCallingIsGranted givenALocalAction {
        condition.allowSelectors(DST_CHAIN_ID, _entry(address(dao), DAO.setMetadata.selector));

        Action[] memory actions = new Action[](1);
        actions[0].to = address(dao);
        actions[0].data = abi.encodeCall(DAO.setMetadata, ("meta"));

        assertFalse(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenALocalNativeTransfer() external whenCallingIsGranted givenALocalAction {
        Action[] memory actions = new Action[](1);
        actions[0].to = carol;
        actions[0].value = 1 ether;
        actions[0].data = "";

        // It should return false when not allowed
        assertFalse(_isGranted(_executeCalldata(actions)));

        // It should return true when allowed on the current chain
        condition.allowNativeTransfers(carol);
        assertTrue(_isGranted(_executeCalldata(actions)));

        // It should return false when value is 0 and calldata is empty
        actions[0].value = 0;
        assertFalse(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenALocalCallWithValueButNativeTransfersNotAllowed()
        external
        whenCallingIsGranted
        givenALocalAction
    {
        condition.allowSelectors(_entry(address(dao), DAO.setMetadata.selector));

        Action[] memory actions = new Action[](1);
        actions[0].to = address(dao);
        actions[0].value = 1 ether;
        actions[0].data = abi.encodeCall(DAO.setMetadata, ("meta"));

        assertFalse(_isGranted(_executeCalldata(actions)));

        // It should return true once native transfers are also allowed
        condition.allowNativeTransfers(address(dao));
        assertTrue(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenALocalActionWithShortCalldata() external view whenCallingIsGranted givenALocalAction {
        // It should return false for calldata of 1-3 bytes
        Action[] memory actions = new Action[](1);
        actions[0].to = address(dao);
        actions[0].data = hex"aabbcc";

        assertFalse(_isGranted(_executeCalldata(actions)));
    }

    // isGranted: cross-chain actions

    modifier givenACrossChainAction() {
        _;
    }

    function test_GivenTheInnerActionIsAllowedOnTheDestinationChain()
        external
        whenCallingIsGranted
        givenACrossChainAction
    {
        // It should return true: the inner action's selector is allowed on the destination chain
        condition.allowSelectors(DST_CHAIN_ID, _entry(remoteContract, REMOTE_SELECTOR));

        Action[] memory actions = new Action[](1);
        actions[0] = _crossChainAction(DST_CHAIN_ID, _remoteCall(0));

        assertTrue(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenTheInnerSelectorIsNotAllowedOnTheDestinationChain()
        external
        view
        whenCallingIsGranted
        givenACrossChainAction
    {
        // It should return false: nothing is allowed for that target yet
        Action[] memory actions = new Action[](1);
        actions[0] = _crossChainAction(DST_CHAIN_ID, _remoteCall(0));

        assertFalse(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenTheInnerActionIsOnlyAllowedOnTheCurrentChain()
        external
        whenCallingIsGranted
        givenACrossChainAction
    {
        // It should return false: the destination chain's allowlist is what counts
        condition.allowSelectors(_entry(remoteContract, REMOTE_SELECTOR)); // current chain only

        Action[] memory actions = new Action[](1);
        actions[0] = _crossChainAction(DST_CHAIN_ID, _remoteCall(0));

        assertFalse(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenTheInnerActionIsAllowedOnADifferentDestinationChain()
        external
        whenCallingIsGranted
        givenACrossChainAction
    {
        // It should return false: the allowance must match the chain the message is forwarded to
        condition.allowSelectors(OTHER_CHAIN_ID, _entry(remoteContract, REMOTE_SELECTOR));

        Action[] memory actions = new Action[](1);
        actions[0] = _crossChainAction(DST_CHAIN_ID, _remoteCall(0));

        assertFalse(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenTheOuterActionIsNotForwardMessage() external whenCallingIsGranted givenACrossChainAction {
        // It should return false when the CrossChainController is called with another selector
        condition.allowSelectors(DST_CHAIN_ID, _entry(remoteContract, REMOTE_SELECTOR));
        condition.allowSelectors(_entry(address(ccc), ICrossChainController.retryMessage.selector));

        Action[] memory actions = new Action[](1);
        actions[0].to = address(ccc);
        actions[0].data = abi.encodeCall(ICrossChainController.retryMessage, (""));

        assertFalse(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenTheOuterActionHasShortCalldata() external whenCallingIsGranted givenACrossChainAction {
        // The target is a CrossChainController, so the local branch is skipped and the
        // selector is read before any length guard. Anything shorter than 4 bytes has no
        // selector to compare, so it cannot be a forwardMessage() call.
        condition.allowNativeTransfers(address(ccc));

        Action[] memory actions = new Action[](1);
        actions[0].to = address(ccc);

        // Empty calldata: a plain native transfer to the CrossChainController
        actions[0].value = 1 ether;
        actions[0].data = "";
        assertFalse(_isGranted(_executeCalldata(actions)));

        // 1 to 3 bytes of calldata
        actions[0].value = 0;
        actions[0].data = hex"aa";
        assertFalse(_isGranted(_executeCalldata(actions)));

        actions[0].data = hex"aabb";
        assertFalse(_isGranted(_executeCalldata(actions)));

        actions[0].data = hex"aabbcc";
        assertFalse(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenAnInnerActionWithValue() external whenCallingIsGranted givenACrossChainAction {
        // The value is paid out of the destination chain executor's balance, so the
        // destination chain's native transfer allowance is what must be granted here
        condition.allowSelectors(DST_CHAIN_ID, _entry(remoteContract, REMOTE_SELECTOR));

        Action[] memory actions = new Action[](1);
        actions[0] = _crossChainAction(DST_CHAIN_ID, _remoteCall(1 ether));

        // It should return false while native transfers are not allowed on the destination chain
        assertFalse(_isGranted(_executeCalldata(actions)));

        // Allowing native transfers on the current chain must not help
        condition.allowNativeTransfers(remoteContract);
        assertFalse(_isGranted(_executeCalldata(actions)));

        // It should return true once native transfers are allowed on the destination chain
        condition.allowNativeTransfers(DST_CHAIN_ID, remoteContract);
        assertTrue(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenAnInnerPureNativeTransfer() external whenCallingIsGranted givenACrossChainAction {
        // It should follow the same rules as a local native transfer, on the destination chain
        Action[] memory innerActions = new Action[](1);
        innerActions[0].to = remoteContract;
        innerActions[0].value = 1 ether;
        innerActions[0].data = "";

        Action[] memory actions = new Action[](1);
        actions[0] = _crossChainAction(DST_CHAIN_ID, innerActions);

        // Not allowed yet
        assertFalse(_isGranted(_executeCalldata(actions)));

        // Allowed on the destination chain
        condition.allowNativeTransfers(DST_CHAIN_ID, remoteContract);
        assertTrue(_isGranted(_executeCalldata(actions)));

        // A zero-value empty action is never allowed
        innerActions[0].value = 0;
        actions[0] = _crossChainAction(DST_CHAIN_ID, innerActions);
        assertFalse(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenAnInnerActionWithShortCalldata() external whenCallingIsGranted givenACrossChainAction {
        // It should return false for calldata of 1-3 bytes
        condition.allowSelectors(DST_CHAIN_ID, _entry(remoteContract, REMOTE_SELECTOR));

        Action[] memory innerActions = new Action[](1);
        innerActions[0].to = remoteContract;
        innerActions[0].data = hex"aabbcc";

        Action[] memory actions = new Action[](1);
        actions[0] = _crossChainAction(DST_CHAIN_ID, innerActions);

        assertFalse(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenMultipleInnerActionsWhereOneIsNotAllowed() external whenCallingIsGranted givenACrossChainAction {
        // It should return false if any inner action fails the check
        condition.allowSelectors(DST_CHAIN_ID, _entry(remoteContract, REMOTE_SELECTOR));

        Action[] memory innerActions = new Action[](2);
        innerActions[0].to = remoteContract;
        innerActions[0].data = abi.encodeWithSelector(REMOTE_SELECTOR, carol, 1000);
        innerActions[1].to = address(0x5678); // Same selector, but this target is not allowed
        innerActions[1].data = abi.encodeWithSelector(REMOTE_SELECTOR, carol, 1000);

        Action[] memory actions = new Action[](1);
        actions[0] = _crossChainAction(DST_CHAIN_ID, innerActions);

        assertFalse(_isGranted(_executeCalldata(actions)));

        // It should return true once the second target is allowed too
        condition.allowSelectors(DST_CHAIN_ID, _entry(address(0x5678), REMOTE_SELECTOR));
        assertTrue(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenAnEmptyInnerActionsArray() external view whenCallingIsGranted givenACrossChainAction {
        // It should return true: there is nothing to disallow
        Action[] memory innerActions;

        Action[] memory actions = new Action[](1);
        actions[0] = _crossChainAction(DST_CHAIN_ID, innerActions);

        assertTrue(_isGranted(_executeCalldata(actions)));
    }

    function test_GivenAMixedBatchOfLocalAndCrossChainActions() external whenCallingIsGranted {
        // It should validate each action against its own chain's allowlist
        // Two local actions
        condition.allowSelectors(_entry(address(dao), DAO.setMetadata.selector));
        condition.allowNativeTransfers(carol);
        // Two remote actions, each on a different destination chain
        condition.allowSelectors(DST_CHAIN_ID, _entry(remoteContract, REMOTE_SELECTOR));
        condition.allowSelectors(OTHER_CHAIN_ID, _entry(remoteTarget, OTHER_REMOTE_SELECTOR));

        Action[] memory otherChainInner = new Action[](1);
        otherChainInner[0].to = remoteTarget;
        otherChainInner[0].data = abi.encodeCall(IRemoteContract.doSomethingElse, (1000));

        Action[] memory actions = new Action[](4);
        // Local: allowed function call
        actions[0].to = address(dao);
        actions[0].data = abi.encodeCall(DAO.setMetadata, ("meta"));
        // Local: allowed native transfer
        actions[1].to = carol;
        actions[1].value = 1 ether;
        actions[1].data = "";
        // Remote on DST_CHAIN_ID
        actions[2] = _crossChainAction(DST_CHAIN_ID, _remoteCall(0));
        // Remote on OTHER_CHAIN_ID
        actions[3] = _crossChainAction(OTHER_CHAIN_ID, otherChainInner);

        assertTrue(_isGranted(_executeCalldata(actions)));

        // It should return false as soon as the first local action gets disallowed
        condition.disallowSelectors(_entry(address(dao), DAO.setMetadata.selector));
        assertFalse(_isGranted(_executeCalldata(actions)));
        condition.allowSelectors(_entry(address(dao), DAO.setMetadata.selector));

        // It should return false as soon as the local native transfer gets disallowed
        condition.disallowNativeTransfers(carol);
        assertFalse(_isGranted(_executeCalldata(actions)));
        condition.allowNativeTransfers(carol);

        // It should return false as soon as the first remote action gets disallowed
        condition.disallowSelectors(DST_CHAIN_ID, _entry(remoteContract, REMOTE_SELECTOR));
        assertFalse(_isGranted(_executeCalldata(actions)));
        condition.allowSelectors(DST_CHAIN_ID, _entry(remoteContract, REMOTE_SELECTOR));

        // It should return false as soon as the second remote action gets disallowed
        condition.disallowSelectors(OTHER_CHAIN_ID, _entry(remoteTarget, OTHER_REMOTE_SELECTOR));
        assertFalse(_isGranted(_executeCalldata(actions)));

        // It should return true again once everything is restored
        condition.allowSelectors(OTHER_CHAIN_ID, _entry(remoteTarget, OTHER_REMOTE_SELECTOR));
        assertTrue(_isGranted(_executeCalldata(actions)));
    }

    // supportsInterface

    function test_WhenCallingSupportsInterface() external view {
        // It should return true for the IPermissionCondition interface ID
        assertTrue(condition.supportsInterface(type(IPermissionCondition).interfaceId));
        // It should return true for the ERC165 interface ID
        assertTrue(condition.supportsInterface(type(IERC165Upgradeable).interfaceId));
        // It should return false for a random interface ID
        assertFalse(condition.supportsInterface(0x12345678));
        // It should return false for the null interface ID (0xffffffff)
        assertFalse(condition.supportsInterface(0xffffffff));
    }
}
