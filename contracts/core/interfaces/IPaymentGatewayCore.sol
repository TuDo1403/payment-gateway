// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

interface IPaymentGatewayReceiver is IERC165 {
    struct Receipt {
        address token;
        address from;
        address to;
        bytes assetData;
        bytes requestArgs;
    }

    function canReceiveRequest() external pure returns (bytes4);
}

interface IPaymentGatewayCore {
    error PaymentGatewayCore__UnsafeRecipient();

    event PayedAndCalled(
        address indexed operator,
        uint256 indexed paymentType,
        Request request,
        Payment payment
    );

    struct Payment {
        address token;
        address from;
        address to;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
        bytes extraData;
    }

    struct Request {
        address to;
        bytes4 fnSelector;
        bytes requestArgs;
    }

    function payAndCall(
        Request calldata request_,
        Payment calldata payment_
    ) external payable;
}
