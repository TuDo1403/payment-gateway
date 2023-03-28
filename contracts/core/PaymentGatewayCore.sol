// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {
    IPaymentGatewayCore,
    IPaymentGatewayReceiver
} from "./interfaces/IPaymentGatewayCore.sol";

import {ErrorHandler} from "../libraries/ErrorHandler.sol";

abstract contract PaymentGatewayCore is
    Context,
    ReentrancyGuard,
    IPaymentGatewayCore
{
    using ErrorHandler for bool;

    function _pay(
        address sender_,
        uint8 paymentType_,
        Payment calldata payment_
    ) internal virtual;

    function _beforePayment(
        address sender_,
        Request memory request_,
        Payment memory payment_
    ) internal virtual returns (uint8 paymentType);

    function _afterPayment(
        address sender_,
        uint8 paymentType_,
        Request memory request_,
        Payment memory payment_
    ) internal virtual {
        emit PayedAndCalled(sender_, paymentType_, request_, payment_);
    }

    function payAndCall(
        Request calldata request_,
        Payment calldata payment_
    ) external payable virtual nonReentrant {
        address sender = _msgSender();

        uint8 paymentType = _beforePayment(sender, request_, payment_);

        _pay(sender, paymentType, payment_);

        _call(request_, payment_);

        _afterPayment(sender, paymentType, request_, payment_);
    }

    function _call(Request memory request_, Payment memory payment_) internal {
        if (
            IPaymentGatewayReceiver(request_.to).canReceiveRequest() !=
            IPaymentGatewayReceiver.canReceiveRequest.selector
        ) revert PaymentGatewayCore__UnsafeRecipient();

        bool success;
        bytes memory returnOrRevertData;
        (success, returnOrRevertData) = request_.to.call(
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
