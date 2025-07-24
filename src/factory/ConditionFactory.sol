// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.22;

import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {ExecuteSelectorCondition} from "../ExecuteSelectorCondition.sol";
import {SelectorCondition} from "../SelectorCondition.sol";

/// @title ConditionFactory
/// @author AragonX 2025
/// @notice A factory used to deploy new condition instances
contract ConditionFactory {
    event ExecuteSelectorConditionDeployed(ExecuteSelectorCondition newContract);
    event SelectorConditionDeployed(SelectorCondition newContract);

    function deployExecuteSelectorCondition(IDAO _dao, ExecuteSelectorCondition.SelectorTarget[] memory _initialEntries)
        public
        returns (ExecuteSelectorCondition newContract)
    {
        newContract = new ExecuteSelectorCondition(_dao, _initialEntries);
        emit ExecuteSelectorConditionDeployed(newContract);
        return newContract;
    }

    function deploySelectorCondition(IDAO _dao, bytes4[] memory _initialSelectors)
        public
        returns (SelectorCondition newContract)
    {
        newContract = new SelectorCondition(_dao, _initialSelectors);
        emit SelectorConditionDeployed(newContract);
        return newContract;
    }
}
