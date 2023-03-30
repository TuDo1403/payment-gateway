// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IPermit2} from "../utils/permit2/interfaces/IPermit2.sol";

import {IPaymentGatewayCore} from "../core/interfaces/IPaymentGatewayCore.sol";

interface IPaymentGateway is IPaymentGatewayCore {
    error PaymentGateway__OnlyEOA(address);
    error PaymentGateway__InvalidArgument();
    error PaymentGateway__InsufficientAllowance();
    error PaymentGateway__InvalidToken(address token);
    error PaymentGateway__UnathorizedCall(address caller);
    error PaymentGateway__PermissionNotGranted(address token);

    enum AssetLabel {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155,
        INVALID
    }

    event Permit2Changed(
        address indexed operator,
        IPermit2 indexed from,
        IPermit2 indexed to
    );

    event Refunded(address indexed to, uint256 indexed amount);

    function pause() external;

    function unpause() external;
}
