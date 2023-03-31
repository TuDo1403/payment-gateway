// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

error ErrorHandler__ExecutionFailed();

/**
 *@title ErrorHandler
 *@dev A library for handling revert errors. If a function call fails, this library will revert the transaction with the
 *appropriate error message. The error message is either the revert reason returned by the failed function, or a default
 *message "Execution failed" if no revert reason is provided.
 */
library ErrorHandler {
    /**
     *@dev Reverts the transaction with the appropriate error message if the function call fails.
     *@param ok_ A boolean indicating if the function call was successful or not.
     *@param revertData_ The data returned by the failed function call.
     *If the function call succeeded, revertData_ should be an empty bytes array.
     *If the function call failed, revertData_ should contain the revert reason encoded as bytes.
     */
    function handleRevertIfNotSuccess(
        bool ok_,
        bytes memory revertData_
    ) internal pure {
        assembly {
            if iszero(ok_) {
                let revertLength := mload(revertData_)
                if iszero(iszero(revertLength)) {
                    // Start of revert data bytes. The 0x20 offset is always the same.
                    revert(add(revertData_, 0x20), revertLength)
                }

                // Default revert message if no revert reason is provided
                //  revert ErrorHandler__ExecutionFailed()
                mstore(0x00, 0xa94eec76)
                revert(0x1c, 0x04)
            }
        }
    }
}
