// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IFundRecoverable {
    struct RecoverCallData {
        address target;
        uint256 value;
        bytes callData;
    }

    event Executed(address indexed operator, bytes[] results);

    function recover(RecoverCallData[] calldata calldata_) external;
}
