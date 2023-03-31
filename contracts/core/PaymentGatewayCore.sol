// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {
    IPaymentGatewayCore,
    IPaymentGatewayReceiver
} from "./interfaces/IPaymentGatewayCore.sol";

import {ErrorHandler} from "../libraries/ErrorHandler.sol";

/**
 *@title PaymentGatewayCore
 *@dev This contract is the core implementation of a payment gateway. It allows users to pay for a certain service and execute a specific function of a receiver contract with *provided arguments.
 */
abstract contract PaymentGatewayCore is
    Context,
    ReentrancyGuard,
    IPaymentGatewayCore
{
    using ErrorHandler for bool;

    /**
     * @dev This function is used to execute the payment for the service.
     * @param sender_ The address of the sender.
     * @param paymentType_ An integer that represents the type of payment being made.
     * @param payment_ A Payment struct that contains the payment details.
     */
    function _pay(
        address sender_,
        uint8 paymentType_,
        Payment calldata payment_
    ) internal virtual;

    /**
     * @dev This function is called before payment execution.
     * @param sender_ The address of the sender.
     * @param request_ A Request struct that contains the details of the request to be executed.
     * @param payment_ A Payment struct that contains the payment details.
     * @return paymentType An integer that represents the type of payment being made.
     */
    function _beforePayment(
        address sender_,
        Request memory request_,
        Payment memory payment_
    ) internal virtual returns (uint8 paymentType);

    /**
     * @dev This function is called after payment execution.
     * @param sender_ The address of the sender.
     * @param paymentType_ An integer that represents the type of payment being made.
     * @param request_ A Request struct that contains the details of the request to be executed.
     * @param payment_ A Payment struct that contains the payment details.
     */
    function _afterPayment(
        address sender_,
        uint8 paymentType_,
        Request memory request_,
        Payment memory payment_
    ) internal virtual {
        emit PayedAndCalled(sender_, paymentType_, request_, payment_);
    }

    /**
     * @dev This function is used to pay for a service and execute a specific function of a receiver contract with provided arguments.
     * @param request_ A Request struct that contains the details of the request to be executed.
     * @param payment_ A Payment struct that contains the payment details.
     */
    /// @inheritdoc IPaymentGatewayCore
    function payAndCall(
        Request calldata request_,
        Payment calldata payment_
    ) external payable virtual nonReentrant {
        address sender = _msgSender();

        uint8 paymentType = _beforePayment(sender, request_, payment_);

        _pay(sender, paymentType, payment_);

        _afterPayment(sender, paymentType, request_, payment_);

        _call(request_, payment_);
    }

    /**
     * @dev This function is used to call the function of the receiver contract with the provided arguments.
     * @param request_ A Request struct that contains the details of the request to be executed.
     * @param payment_ A Payment struct that contains the payment details.
     */
    function _call(Request memory request_, Payment memory payment_) internal {
        if (
            IPaymentGatewayReceiver(request_.to).canReceiveRequest() !=
            IPaymentGatewayReceiver.canReceiveRequest.selector
        ) revert PaymentGatewayCore__UnsafeRecipient();

        (bool success, bytes memory returnOrRevertData) = request_.to.call(
            abi.encodePacked(
                request_.fnSelector,
                abi.encode(
                    IPaymentGatewayReceiver.Receipt(
                        payment_.token,
                        payment_.from,
                        payment_.to,
                        payment_.extraData,
                        request_.requestArgs
                    )
                )
            )
        );
        success.handleRevertIfNotSuccess(returnOrRevertData);
    }
}
