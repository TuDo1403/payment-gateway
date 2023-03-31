// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

import {ErrorHandler} from "../libraries/ErrorHandler.sol";

import {IFundRecoverable} from "./interfaces/IFundRecoverable.sol";

/**
 *@title FundRecoverable
 *@dev This abstract contract provides a recover function to recover accidentally sent tokens or ETH.
 *The contract can execute multiple arbitrary calls in a single transaction.
 *To use this contract, another contract must inherit this abstract contract and override the _beforeRecover function.
 *The _beforeRecover function can be used to implement access control or other checks before executing the recover function.
 */
abstract contract FundRecoverable is Context, IFundRecoverable {
    using ErrorHandler for bool;

    /// @inheritdoc IFundRecoverable
    function recover(RecoverCallData[] calldata calldata_) external virtual {
        _beforeRecover("");
        _recover(calldata_);
    }

    /**
     * @dev A function that is called before the recover function is executed.
     * Override this function to add access control or other checks.
     * @param data_ A bytes parameter that can be used to pass additional data or parameters.
     */
    function _beforeRecover(bytes memory data_) internal virtual;

    /**
     * @dev Internal function that executes the recover function.
     * @param calldata_ An array of RecoverCallData structs representing the calls to execute.
     */
    function _recover(RecoverCallData[] calldata calldata_) internal virtual {
        uint256 length = calldata_.length;
        bytes[] memory results = new bytes[](length);

        bool success;
        bytes memory returnOrRevertData;
        for (uint256 i; i < length; ) {
            (success, returnOrRevertData) = calldata_[i].target.call{
                value: calldata_[i].value
            }(calldata_[i].callData);

            success.handleRevertIfNotSuccess(returnOrRevertData);

            results[i] = returnOrRevertData;

            unchecked {
                ++i;
            }
        }

        emit Executed(_msgSender(), results);
    }
}
