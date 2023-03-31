// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

import {
    ErrorHandler,
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

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
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
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using ErrorHandler for bool;
    using ERC165Checker for address;

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
        (
            Payment memory payment,
            Request memory request
        ) = __decodePaymentAndRequest(from_, data_, abi.encode(id_, value_));

        uint8 paymentType = _beforePayment(operator_, request, payment);

        address paymentToken = payment.token;

        if (paymentType != uint8(AssetLabel.ERC1155))
            revert PaymentGateway__UnathorizedCall(paymentToken);

        __safeERC1155TransferFrom(
            paymentToken,
            address(this),
            payment.to,
            id_,
            value_
        );

        _afterPayment(paymentToken, paymentType, request, payment);

        _call(request, payment);

        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator_,
        address from_,
        uint256[] calldata ids_,
        uint256[] calldata values_,
        bytes calldata data_
    ) external override nonReentrant returns (bytes4) {
        (
            Payment memory payment,
            Request memory request
        ) = __decodePaymentAndRequest(from_, data_, abi.encode(ids_, values_));

        uint8 paymentType = _beforePayment(operator_, request, payment);

        address paymentToken = payment.token;

        if (paymentType != uint8(AssetLabel.ERC1155))
            revert PaymentGateway__UnathorizedCall(paymentToken);

        __safeERC1155BatchTransferFrom(
            paymentToken,
            address(this),
            payment.to,
            ids_,
            values_
        );

        _afterPayment(paymentToken, paymentType, request, payment);

        _call(request, payment);

        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address operator_,
        address from_,
        uint256 tokenId_,
        bytes calldata data_
    ) external override nonReentrant returns (bytes4) {
        (
            Payment memory payment,
            Request memory request
        ) = __decodePaymentAndRequest(from_, data_, abi.encode(tokenId_));

        uint8 paymentType = _beforePayment(operator_, request, payment);

        address paymentToken = payment.token;

        if (paymentType != uint8(AssetLabel.ERC721))
            revert PaymentGateway__UnathorizedCall(paymentToken);

        __safeERC721TransferFrom(paymentToken, from_, payment.to, tokenId_);

        _afterPayment(paymentToken, paymentType, request, payment);

        _call(request, payment);

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
                    payment_.permission.deadline,
                    payment_.permission.signature
                );
            else if (paymentType_ == uint8(AssetLabel.ERC1155)) {
                (bool isBatchTransfer, bytes memory transferData) = abi.decode(
                    payment_.extraData,
                    (bool, bytes)
                );
                if (isBatchTransfer) {
                    (uint256 tokenId, uint256 amount) = abi.decode(
                        transferData,
                        (uint256, uint256)
                    );

                    __safeERC1155TransferFrom(
                        payment_.token,
                        payment_.from,
                        payment_.to,
                        tokenId,
                        amount
                    );
                } else {
                    (uint256[] memory ids, uint256[] memory amounts) = abi
                        .decode(transferData, (uint256[], uint256[]));

                    __safeERC1155BatchTransferFrom(
                        payment_.token,
                        payment_.from,
                        payment_.to,
                        ids,
                        amounts
                    );
                }
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
    ) internal virtual override whenNotPaused returns (uint8 paymentType) {
        if (sender_ != tx.origin) revert PaymentGateway__OnlyEOA(sender_);
        if (request_.fnSelector == 0) revert PaymentGateway__InvalidArgument();

        address paymentToken = payment_.token;
        paymentType = paymentToken == address(0)
            ? uint8(AssetLabel.NATIVE)
            : !paymentToken.supportsInterface(type(IERC165).interfaceId)
            ? uint8(AssetLabel.ERC20)
            : paymentToken.supportsInterface(type(IERC721).interfaceId)
            ? uint8(AssetLabel.ERC721)
            : paymentToken.supportsInterface(type(IERC1155).interfaceId)
            ? uint8(AssetLabel.ERC1155)
            : uint8(AssetLabel.INVALID);
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

        __safeERC721TransferFrom(token_, from_, to_, tokenId_);
    }

    function __handleERC20Transfer(Payment calldata payment_) private {
        uint256 sendAmount = abi.decode(payment_.extraData, (uint256));

        address from = payment_.from;
        address paymentToken = payment_.token;

        IPermit2 _permit2 = permit2;
        (uint256 allowed, bool supportedEIP2612) = __viewERC20SelfAllowance(
            _permit2,
            paymentToken,
            from
        );

        if (allowed < sendAmount) {
            if (supportedEIP2612) {
                (bytes32 r, bytes32 s, uint8 v) = payment_
                    .permission
                    .signature
                    .split();

                uint256 permitAmount = abi.decode(
                    payment_.permission.extraData,
                    (uint256)
                );

                if (permitAmount < sendAmount)
                    revert PaymentGateway__InsufficientAllowance();

                IERC20Permit(paymentToken).permit(
                    from,
                    address(this),
                    permitAmount,
                    payment_.permission.deadline,
                    v,
                    r,
                    s
                );
            } else {
                (uint160 permitAmount, uint48 expiration, uint48 nonce) = abi
                    .decode(
                        payment_.permission.extraData,
                        (uint160, uint48, uint48)
                    );

                if (permitAmount < sendAmount)
                    revert PaymentGateway__InsufficientAllowance();

                _permit2.permit({
                    owner: from,
                    permitSingle: IPermit2.PermitSingle({
                        details: IPermit2.PermitDetails({
                            token: paymentToken,
                            amount: permitAmount,
                            expiration: expiration,
                            nonce: nonce
                        }),
                        spender: address(this),
                        sigDeadline: payment_.permission.deadline
                    }),
                    signature: payment_.permission.signature
                });
            }
        }

        __safeERC20TransferFrom(
            supportedEIP2612,
            _permit2,
            paymentToken,
            from,
            payment_.to,
            sendAmount
        );
    }

    function __handleNativeTransfer(
        address sender_,
        Payment calldata payment_
    ) private {
        uint256 sendAmount = abi.decode(payment_.extraData, (uint256));
        uint256 refundAmount = msg.value - sendAmount;
        __safeNativeTransfer(payment_.to, sendAmount);

        __refundNative(sender_, refundAmount);
    }

    function __refundNative(address to_, uint256 amount_) private {
        __safeNativeTransfer(to_, amount_);
        emit Refunded(to_, amount_);
    }

    function __safeNativeTransfer(address to_, uint256 amount_) private {
        uint256 _balance = to_.balance;

        (bool success, bytes memory returnOrRevertData) = to_.call{
            value: amount_
        }("");

        success.handleRevertIfNotSuccess(returnOrRevertData);

        _balance = to_.balance - _balance;

        if (_balance < amount_) revert PaymentGateway__PaymentFailed();
    }

    function __safeERC20TransferFrom(
        bool supportedEIP2612_,
        IPermit2 permit2_,
        address token_,
        address from_,
        address to_,
        uint256 amount_
    ) private {
        uint256 _balance = IERC20(token_).balanceOf(to_);

        if (supportedEIP2612_)
            IERC20(token_).safeTransferFrom(from_, to_, amount_);
        else permit2_.transferFrom(from_, to_, amount_.toUint160(), token_);

        _balance = IERC20(token_).balanceOf(to_) - _balance;

        if (_balance < amount_) revert PaymentGateway__PaymentFailed();
    }

    function __safeERC721TransferFrom(
        address token_,
        address from_,
        address to_,
        uint256 tokenId_
    ) private {
        uint256 _balance = IERC721(token_).balanceOf(to_);

        IERC721(token_).safeTransferFrom(from_, to_, tokenId_);

        _balance = IERC721(token_).balanceOf(to_) - _balance;

        if (_balance == 0) revert PaymentGateway__PaymentFailed();
    }

    function __safeERC1155TransferFrom(
        address token_,
        address from_,
        address to_,
        uint256 tokenId_,
        uint256 amount_
    ) private {
        uint256 _balance = IERC1155(token_).balanceOf(to_, tokenId_);

        IERC1155(token_).safeTransferFrom(from_, to_, tokenId_, amount_, "");

        _balance = IERC1155(token_).balanceOf(to_, tokenId_) - _balance;

        if (_balance < amount_) revert PaymentGateway__PaymentFailed();
    }

    function __safeERC1155BatchTransferFrom(
        address token_,
        address from_,
        address to_,
        uint256[] memory ids_,
        uint256[] memory amounts_
    ) private {
        address[] memory tos = new address[](1);
        tos[0] = from_;

        uint256[] memory balancesBefore = IERC1155(token_).balanceOfBatch(
            tos,
            ids_
        );

        IERC1155(token_).safeBatchTransferFrom(from_, to_, ids_, amounts_, "");

        uint256[] memory balancesAfter = IERC1155(token_).balanceOfBatch(
            tos,
            ids_
        );

        uint256 length = balancesAfter.length;
        for (uint256 i; i < length; ) {
            if (balancesAfter[i] - balancesBefore[i] < amounts_[i])
                revert PaymentGateway__PaymentFailed();
            unchecked {
                ++i;
            }
        }
    }

    function __viewERC20SelfAllowance(
        IPermit2 permit2_,
        address token_,
        address owner_
    ) private view returns (uint256 allowed, bool supportedEIP2612) {
        (bool success, bytes memory returnOrRevertData) = token_.staticcall(
            abi.encodeCall(IERC20Permit.DOMAIN_SEPARATOR, ())
        );

        if (success) {
            abi.decode(returnOrRevertData, (bytes32));
            supportedEIP2612 = true;
            allowed = IERC20(token_).allowance(owner_, address(this));
        } else {
            allowed = IERC20(token_).allowance(owner_, address(permit2_));
            if (allowed != 0) {
                uint256 expiration;
                (allowed, expiration, ) = permit2_.allowance(
                    owner_,
                    token_,
                    address(this)
                );
                allowed = expiration < block.timestamp ? 0 : allowed;
            }
        }
    }

    function __decodePaymentAndRequest(
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
