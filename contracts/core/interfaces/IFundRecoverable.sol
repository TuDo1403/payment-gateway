// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 *@title IFundRecoverable
 *@dev This contract interface defines the functions and events for a contract that can recover funds through external calls.
 */
interface IFundRecoverable {
    /**
     * @dev Struct containing information required to execute a recover call.
     */
    struct RecoverCallData {
        address target;
        uint256 value;
        bytes callData;
    }

    /**
     * @dev Emitted when the `recover` function is executed.
     * @param operator The address of the account executing the `recover` function.
     * @param results An array of bytes representing the results of each external call made during the `recover` function.
     */
    event Executed(address indexed operator, bytes[] results);

    /**
     * @dev Allows the contract to recover funds through external calls.
     * @param calldata_ An array of `RecoverCallData` structs, each containing the information required to execute a recover call.
     */
    function recover(RecoverCallData[] calldata calldata_) external;
}
