// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.17;

import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {ExecuteSelectorCondition} from "../ExecuteSelectorCondition.sol";
import {SelectorCondition} from "../SelectorCondition.sol";

/// @title ConditionFactory
/// @author AragonX 2025
/// @notice A factory used to deploy new instances of the Condition contract
contract ConditionFactory {
    function deployExecuteSelectorCondition(
        IDAO _dao,
        ExecuteSelectorCondition.InitialTarget[] memory _initialExecuteTargets
    ) public returns (ExecuteSelectorCondition) {
        return new ExecuteSelectorCondition(_dao, _initialExecuteTargets);
    }

    function deploySelectorCondition(
        IDAO _dao,
        bytes4[] memory _initialSelectors
    ) public returns (SelectorCondition) {
        return new SelectorCondition(_dao, _initialSelectors);
    }
}
