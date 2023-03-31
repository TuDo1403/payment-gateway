// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IPermit2} from "../utils/permit2/interfaces/IPermit2.sol";

import {IPaymentGatewayCore} from "../core/interfaces/IPaymentGatewayCore.sol";

/**
 *@title IPaymentGateway
 *@dev The interface for the PaymentGateway contract, which facilitates payments and calls to external contracts. 
 This contract inherits from IPaymentGatewayCore and provides additional functionality for managing payments and pausing the contract.
 */
interface IPaymentGateway is IPaymentGatewayCore {
    /**
     *@dev Error message when a payment fails.
     */
    error PaymentGateway__PaymentFailed();
    /**
     *@dev Error message when a non-EOA account attempts to make a payment.
     *@param account The address of the account that attempted the payment.
     */
    error PaymentGateway__OnlyEOA(address account);
    /**
     *@dev Error message when an invalid argument is passed to a function.
     */
    error PaymentGateway__InvalidArgument();
    /**
     *@dev Error message when the allowance is insufficient for a payment.
     */
    error PaymentGateway__InsufficientAllowance();
    /**
     *@dev Error message when an invalid token is passed to a function.
     *@param token The address of the invalid token.
     */
    error PaymentGateway__InvalidToken(address token);
    /**
     *@dev Error message when an unauthorized call is made.
     *@param caller The address of the unauthorized caller.
     */
    error PaymentGateway__UnathorizedCall(address caller);
    /**
     *@dev Error message when permission is not granted for a token.
     *@param token The address of the token for which permission is not granted.
     */
    error PaymentGateway__PermissionNotGranted(address token);

    /**
     *@dev Enum representing different asset types for payments.
     */
    enum AssetLabel {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155,
        INVALID
    }

    /**
     *@dev Emitted when the permit2 contract is changed.
     *@param operator The address of the operator who made the change.
     *@param from The old permit2 contract.
     *@param to The new permit2 contract.
     */
    event Permit2Changed(
        address indexed operator,
        IPermit2 indexed from,
        IPermit2 indexed to
    );

    /**
     *@dev Emitted when a refund is made.
     *@param to The address of the account that received the refund.
     *@param amount The amount of tokens refunded.
     */
    event Refunded(address indexed to, uint256 indexed amount);

    /**
     *@dev Pauses the contract, preventing any new payments or calls.
     */
    function pause() external;

    /**
     *@dev Unpauses the contract, allowing payments and calls to resume.
     */
    function unpause() external;
}
