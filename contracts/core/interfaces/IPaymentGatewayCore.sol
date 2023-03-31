// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 *@title IPaymentGatewayReceiver
 *@dev This contract interface extends IERC165 and defines functions and events for a payment gateway receiver contract.
 */
interface IPaymentGatewayReceiver is IERC165 {
    /**
     * @dev Struct containing information about a payment gateway receipt.
     */
    struct Receipt {
        address token;
        address from;
        address to;
        bytes assetData;
        bytes requestArgs;
    }

    /**
     * @dev Returns the bytes4 interface identifier for the canReceiveRequest function.
     */
    function canReceiveRequest() external pure returns (bytes4);
}

/**
 *@title IPaymentGatewayCore
 *@dev This contract interface defines functions and events for a payment gateway core contract.
 */
interface IPaymentGatewayCore {
    /**
     *@dev Error message when an unsafe recipient is detected.
     */
    error PaymentGatewayCore__UnsafeRecipient();

    /**
     *@dev Emitted when a payment is made and a request is called.
     *@param operator The address of the account making the payment and calling the request.
     *@param paymentType The type of payment being made.
     *@param request The Request struct containing information about the request being called.
     *@param payment The Payment struct containing information about the payment being made.
     */
    event PayedAndCalled(
        address indexed operator,
        uint256 indexed paymentType,
        Request request,
        Payment payment
    );

    /**
     *@dev Struct containing information about a payment.
     */
    struct Payment {
        address token;
        address from;
        address to;
        bytes extraData;
        Permission permission;
    }

    /**
     *@dev Struct containing information about a permission.
     */
    struct Permission {
        uint256 deadline;
        bytes signature;
        bytes extraData;
    }

    /**
     *@dev Struct containing information about a request.
     */
    struct Request {
        address to;
        bytes4 fnSelector;
        bytes requestArgs;
    }

    /**
     *@dev Allows the payment gateway to make a payment and call a request.
     *@param request_ The Request struct containing information about the request to be called.
     *@param payment_ The Payment struct containing information about the payment to be made.
     */
    function payAndCall(
        Request calldata request_,
        Payment calldata payment_
    ) external payable;
}
