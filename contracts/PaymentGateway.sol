// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

import {
    PaymentGatewayCore,
    IPaymentGatewayCore
} from "./core/PaymentGatewayCore.sol";

import {FundRecoverable} from "./core/FundRecoverable.sol";

import {
    IERC20,
    IERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {
    IERC721,
    IERC721Receiver
} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {
    IERC1155,
    IERC1155Receiver
} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC4494} from "./eip/interfaces/IERC4494.sol";
import {IPermit2, IPaymentGateway} from "./interfaces/IPaymentGateway.sol";

import {SigUtil} from "./libraries/SigUtil.sol";

import {
    SafeCurrencyTransferHandler
} from "./libraries/SafeCurrencyTransferHandler.sol";
import {
    IERC165,
    ERC165Checker
} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

contract PaymentGateway is
    Ownable,
    Pausable,
    FundRecoverable,
    IPaymentGateway,
    IERC721Receiver,
    IERC1155Receiver,
    PaymentGatewayCore
{
    using SigUtil for bytes;
    using ERC165Checker for address;
    using SafeCurrencyTransferHandler for address;

    IPermit2 public permit2;

    constructor(IPermit2 permit2_) payable Ownable() {
        _setPermit2(permit2_);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setPermit2(IPermit2 permit2_) external onlyOwner {
        _setPermit2(permit2_);
    }

    function onERC1155Received(
        address operator_,
        address from_,
        uint256 id_,
        uint256 value_,
        bytes calldata data_
    ) external override nonReentrant returns (bytes4) {
        (Payment memory payment, Request memory request) = __decodeData(
            from_,
            data_,
            abi.encode(id_, value_)
        );
        uint8 paymentType = _beforePayment(operator_, request, payment);
        address paymentToken = payment.token;
        if (paymentType != uint8(AssetLabel.ERC1155))
            revert PaymentGateway__UnathorizedCall(paymentToken);

        __handleERC1155Transfer({
            token_: paymentToken,
            from_: address(this),
            to_: payment.to,
            isBatchTransfer_: false,
            transferData_: payment.extraData
        });

        _call(request, payment);

        _afterPayment(paymentToken, paymentType, request, payment);

        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator_,
        address from_,
        uint256[] calldata ids_,
        uint256[] calldata values_,
        bytes calldata data_
    ) external override nonReentrant returns (bytes4) {
        (Payment memory payment, Request memory request) = __decodeData(
            from_,
            data_,
            abi.encode(ids_, values_)
        );

        uint8 paymentType = _beforePayment(operator_, request, payment);
        address paymentToken = payment.token;
        if (paymentType != uint8(AssetLabel.ERC1155))
            revert PaymentGateway__UnathorizedCall(paymentToken);

        __handleERC1155Transfer({
            token_: paymentToken,
            from_: address(this),
            to_: payment.to,
            isBatchTransfer_: true,
            transferData_: payment.extraData
        });

        _call(request, payment);

        _afterPayment(paymentToken, paymentType, request, payment);

        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address operator_,
        address from_,
        uint256 tokenId_,
        bytes calldata data_
    ) external override nonReentrant returns (bytes4) {
        (Payment memory payment, Request memory request) = __decodeData(
            from_,
            data_,
            abi.encode(tokenId_)
        );

        uint8 paymentType = _beforePayment(operator_, request, payment);
        address paymentToken = payment.token;
        if (paymentType != uint8(AssetLabel.ERC721))
            revert PaymentGateway__UnathorizedCall(paymentToken);

        __handleERC721Transfer({
            token_: paymentToken,
            from_: address(this),
            to_: payment.to,
            tokenId_: tokenId_,
            deadline_: 0,
            signature_: ""
        });

        _call(request, payment);

        _afterPayment(paymentToken, paymentType, request, payment);

        return IERC721Receiver.onERC721Received.selector;
    }

    function supportsInterface(
        bytes4 interfaceId_
    ) external pure override returns (bool) {
        return
            interfaceId_ == type(IERC165).interfaceId ||
            interfaceId_ == type(IPaymentGateway).interfaceId ||
            interfaceId_ == type(IERC721Receiver).interfaceId ||
            interfaceId_ == type(IERC1155Receiver).interfaceId ||
            interfaceId_ == type(IPaymentGatewayCore).interfaceId;
    }

    function _setPermit2(IPermit2 permit2_) internal {
        emit Permit2Changed(_msgSender(), permit2, permit2_);
        permit2 = permit2_;
    }

    function _pay(
        address sender_,
        uint8 paymentType_,
        Payment calldata payment_
    ) internal override {
        if (paymentType_ == uint8(AssetLabel.NATIVE)) {
            __handleNativeTransfer(sender_, payment_);
            return;
        }

        if (paymentType_ == uint8(AssetLabel.ERC20))
            __handleERC20Transfer(payment_);
        else {
            if (paymentType_ == uint8(AssetLabel.ERC721))
                __handleERC721Transfer(
                    payment_.token,
                    payment_.from,
                    payment_.to,
                    abi.decode(payment_.extraData, (uint256)),
                    payment_.deadline,
                    payment_.signature
                );
            else if (paymentType_ == uint8(AssetLabel.ERC1155)) {
                (bool isBatchTransfer, bytes memory transferData) = abi.decode(
                    payment_.extraData,
                    (bool, bytes)
                );
                __handleERC1155Transfer(
                    payment_.token,
                    payment_.from,
                    payment_.to,
                    isBatchTransfer,
                    transferData
                );
            } else revert PaymentGateway__InvalidToken(payment_.token);
        }

        if (msg.value != 0) __refundNative(sender_, msg.value);
    }

    function _beforeRecover(bytes memory) internal view override {
        _requirePaused();
    }

    function _beforePayment(
        address sender_,
        Request memory request_,
        Payment memory payment_
    ) internal virtual override returns (uint8 paymentType) {
        if (request_.fnSelector == 0 || payment_.to == address(0))
            revert PaymentGateway__InvalidArgument();

        address paymentToken = payment_.token;
        if (paymentToken == address(0)) return uint8(AssetLabel.NATIVE);

        if (paymentToken.code.length == 0)
            revert PaymentGateway__InvalidToken(paymentToken);

        if (!paymentToken.supportsInterface(type(IERC165).interfaceId))
            return uint8(AssetLabel.ERC20);
        else {
            if (paymentToken.supportsInterface(type(IERC721).interfaceId))
                return uint8(AssetLabel.ERC721);
            else if (
                paymentToken.supportsInterface(type(IERC1155).interfaceId)
            ) return uint8(AssetLabel.ERC1155);
            else revert PaymentGateway__InvalidToken(paymentToken);
        }
    }

    function __handleERC1155Transfer(
        address token_,
        address from_,
        address to_,
        bool isBatchTransfer_,
        bytes memory transferData_
    ) private {
        if (isBatchTransfer_) {
            (uint256 tokenId, uint256 amount) = abi.decode(
                transferData_,
                (uint256, uint256)
            );

            IERC1155(token_).safeTransferFrom(from_, to_, tokenId, amount, "");
        } else {
            (uint256[] memory ids, uint256[] memory amounts) = abi.decode(
                transferData_,
                (uint256[], uint256[])
            );

            IERC1155(token_).safeBatchTransferFrom(
                from_,
                to_,
                ids,
                amounts,
                ""
            );
        }
    }

    function __handleERC721Transfer(
        address token_,
        address from_,
        address to_,
        uint256 tokenId_,
        uint256 deadline_,
        bytes memory signature_
    ) private {
        if (
            !(deadline_ == 0 ||
                signature_.length == 0 ||
                IERC721(token_).getApproved(tokenId_) == address(this) ||
                IERC721(token_).isApprovedForAll(from_, address(this)))
        ) {
            if (!token_.supportsInterface(type(IERC4494).interfaceId))
                revert PaymentGateway__PermissionNotGranted(token_);

            IERC4494(token_).permit(
                address(this),
                tokenId_,
                deadline_,
                signature_
            );
        }

        IERC721(token_).safeTransferFrom(from_, to_, tokenId_);
    }

    function __handleERC20Transfer(Payment calldata payment_) private {
        uint256 sendAmount = abi.decode(payment_.extraData, (uint256));

        address from = payment_.from;
        address paymentToken = payment_.token;
        if (IERC20(paymentToken).allowance(from, address(this)) < sendAmount) {
            (bytes32 r, bytes32 s, uint8 v) = payment_.signature.split();

            try
                IERC20Permit(paymentToken).permit(
                    from,
                    address(this),
                    sendAmount,
                    payment_.deadline,
                    v,
                    r,
                    s
                )
            {
                paymentToken.safeERC20TransferFrom(
                    from,
                    address(this),
                    sendAmount
                );
            } catch {
                permit2.permitTransferFrom(
                    // The permit message.
                    IPermit2.PermitTransferFrom({
                        permitted: IPermit2.TokenPermissions({
                            token: IERC20(paymentToken),
                            amount: sendAmount
                        }),
                        nonce: payment_.nonce,
                        deadline: payment_.deadline
                    }),
                    // The transfer recipient and amount.
                    IPermit2.SignatureTransferDetails({
                        to: address(this),
                        requestedAmount: sendAmount
                    }),
                    // The owner of the tokens, which must also be
                    // the signer of the message, otherwise this call
                    // will fail.
                    from,
                    // The packed signature that was the result of signing
                    // the EIP712 hash of `permit`.
                    payment_.signature
                );
            }
        }

        paymentToken.safeERC20Transfer(payment_.to, sendAmount);
    }

    function __handleNativeTransfer(
        address sender_,
        Payment calldata payment_
    ) private {
        uint256 sendAmount = abi.decode(payment_.extraData, (uint256));
        uint256 refundAmount = msg.value - sendAmount;
        payment_.to.safeNativeTransfer(sendAmount, "");
        __refundNative(sender_, refundAmount);
    }

    function __refundNative(address to_, uint256 amount_) private {
        to_.safeNativeTransfer(amount_, "");
        emit Refunded(to_, amount_);
    }

    function __decodeData(
        address from_,
        bytes calldata data_,
        bytes memory extraData_
    ) private view returns (Payment memory payment, Request memory request) {
        address sendTo;
        (sendTo, request) = abi.decode(data_, (address, Request));

        payment.to = sendTo;
        payment.from = from_;
        payment.token = _msgSender();
        payment.extraData = extraData_;
    }
}
