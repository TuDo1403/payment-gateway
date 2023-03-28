// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

error SafeCurrencyTransferHandler__TransferFailed();
error SafeCurrencyTransferHandler__InvalidArguments();

library SafeCurrencyTransferHandler {
    address internal constant NATIVE_TOKEN = address(0);

    /**
     * @dev Reverts the transaction if the transfer fails
     * @param token_ Address of the token contract to transfer. If zero address, transfer Ether.
     * @param from_ Address to transfer from
     * @param to_ Address to transfer to
     * @param value_ Amount of tokens or Ether to transfer
     */
    function safeTransferFrom(
        address token_,
        address from_,
        address to_,
        uint256 value_,
        bytes memory data_
    ) internal {
        checkValidTransfer(to_, value_);

        if (
            token_ == NATIVE_TOKEN
                ? nativeTransfer(to_, value_, data_)
                : ERC20TransferFrom(token_, from_, to_, value_)
        ) return;

        revert SafeCurrencyTransferHandler__TransferFailed();
    }

    /**
     * @dev Reverts the transaction if the transfer fails
     * @param token_ Address of the token contract to transfer. If zero address, transfer Ether.
     * @param to_ Address to transfer to
     * @param value_ Amount of tokens or Ether to transfer
     */
    function safeTransfer(
        address token_,
        address to_,
        uint256 value_,
        bytes memory data_
    ) internal {
        checkValidTransfer(to_, value_);

        if (
            token_ == NATIVE_TOKEN
                ? nativeTransfer(to_, value_, data_)
                : ERC20Transfer(token_, to_, value_)
        ) return;

        revert SafeCurrencyTransferHandler__TransferFailed();
    }

    /**
     * @dev Reverts the transaction if the Ether transfer fails
     * @param to_ Address to transfer to
     * @param amount_ Amount of Ether to transfer
     */
    function safeNativeTransfer(
        address to_,
        uint256 amount_,
        bytes memory data_
    ) internal {
        checkValidTransfer(to_, amount_);
        if (!nativeTransfer(to_, amount_, data_))
            revert SafeCurrencyTransferHandler__TransferFailed();
    }

    function safeERC20Transfer(
        address token_,
        address to_,
        uint256 amount_
    ) internal {
        checkValidTransfer(to_, amount_);
        if (!ERC20Transfer(token_, to_, amount_))
            revert SafeCurrencyTransferHandler__TransferFailed();
    }

    function safeERC20TransferFrom(
        address token_,
        address from_,
        address to_,
        uint256 amount_
    ) internal {
        checkValidTransfer(to_, amount_);

        if (!ERC20TransferFrom(token_, from_, to_, amount_))
            revert SafeCurrencyTransferHandler__TransferFailed();
    }

    function nativeTransfer(
        address to_,
        uint256 amount_,
        bytes memory data_
    ) internal returns (bool success) {
        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(
                gas(),
                to_,
                amount_,
                add(data_, 0x20),
                mload(data_),
                0,
                0
            )
        }
    }

    function ERC20Transfer(
        address token_,
        address to_,
        uint256 value_
    ) internal returns (bool success) {
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(
                freeMemoryPointer,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(freeMemoryPointer, 4), to_) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), value_) // Append the "amount" argument.

            success := and(
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                call(gas(), token_, 0, freeMemoryPointer, 68, 0, 32)
            )
        }
    }

    function ERC20TransferFrom(
        address token_,
        address from_,
        address to_,
        uint256 value_
    ) internal returns (bool success) {
        assembly {
            let freeMemoryPointer := mload(0x40)

            mstore(
                freeMemoryPointer,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(freeMemoryPointer, 4), from_)
            mstore(add(freeMemoryPointer, 36), to_)
            mstore(add(freeMemoryPointer, 68), value_)

            success := and(
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                call(gas(), token_, 0, freeMemoryPointer, 100, 0, 32)
            )
        }
    }

    function checkValidTransfer(address to_, uint256 value_) private pure {
        assembly {
            mstore(0x00, 0x6e1604b3)
            if iszero(to_) {
                revert(0x1c, 0x04)
            }
            if iszero(value_) {
                revert(0x1c, 0x04)
            }
        }
    }
}
