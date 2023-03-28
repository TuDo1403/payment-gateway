// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

import {ErrorHandler} from "../libraries/ErrorHandler.sol";

import {IFundRecoverable} from "./interfaces/IFundRecoverable.sol";

abstract contract FundRecoverable is Context, IFundRecoverable {
    using ErrorHandler for bool;

    function recover(RecoverCallData[] calldata calldata_) external virtual {
        _beforeRecover("");
        _recover(calldata_);
    }

    function _beforeRecover(bytes memory) internal virtual;

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
