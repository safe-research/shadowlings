// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.30;

import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "account-abstraction/core/Helpers.sol";
import {IAccount, PackedUserOperation} from "account-abstraction/interfaces/IAccount.sol";

import {Verifier} from "./verifiers/main/Verifier.sol";
import {Verifier as RecoveryVerifier} from "./verifiers/recovery/Verifier.sol";
import {Verifier as RegisterVerifier} from "./verifiers/register/Verifier.sol";

contract Shadowlings is IAccount, Verifier {
    bytes32 private constant _R = bytes32(uint256(keccak256("Shadowlings.r")) - 1);
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    bytes32 public constant TRANSFER_TYPEHASH = keccak256("Transfer(address token,address to,uint256 amount)");

    address private immutable _SELF;
    address public immutable ENTRY_POINT;
    RecoveryVerifier public immutable RECOVERY;
    RegisterVerifier public immutable REGISTER;

    mapping(uint256 => bool) public nullified;

    error NotDelegated();
    error UnsupportedEntryPoint();
    error UnsupportedCall();
    error Nullified();
    error Unauthorized();
    error InvalidProof();
    error TransferFailed();

    event RecoverySaltHash(uint256 saltHash);

    constructor(address entryPoint) {
        _SELF = address(this);
        ENTRY_POINT = entryPoint;
        RECOVERY = new RecoveryVerifier();
        REGISTER = new RegisterVerifier();
    }

    modifier onlyDelegated() {
        require(address(this) != _SELF, NotDelegated());
        _;
    }

    modifier onlyEntryPoint() {
        require(msg.sender == ENTRY_POINT, UnsupportedEntryPoint());
        _;
    }

    receive() external payable onlyDelegated {}

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        onlyEntryPoint
        returns (uint256 validationData)
    {
        bool success;

        bytes4 selector = bytes4(userOp.callData[:4]);
        if (selector == this.execute.selector) {
            (uint256 commit, uint256 nullifier, Proof memory proof) =
                abi.decode(userOp.signature, (uint256, uint256, Proof));
            success = verifyProof(commit, nullifier, userOpHash, proof);
        } else if (selector == this.register.selector) {
            (uint256 saltHash) = abi.decode(userOp.callData[4:], (uint256));
            (uint256 commit, uint256 nullifier, RegisterVerifier.Proof memory proof) =
                abi.decode(userOp.signature, (uint256, uint256, RegisterVerifier.Proof));
            success = verifyRegisterProof(commit, nullifier, userOpHash, saltHash, proof);
        } else {
            revert UnsupportedCall();
        }

        if (missingAccountFunds != 0) {
            assembly ("memory-safe") {
                pop(call(gas(), caller(), missingAccountFunds, 0, 0, 0, 0))
            }
        }

        if (success) {
            validationData = SIG_VALIDATION_SUCCESS;
        } else {
            validationData = SIG_VALIDATION_FAILED;
        }
    }

    function execute(address token, address to, uint256 amount) external onlyEntryPoint returns (bool success) {
        success = _execute(token, to, amount);
    }

    function register(uint256 saltHash) external onlyEntryPoint returns (bool success) {
        emit RecoverySaltHash(saltHash);
        success = true;
    }

    function executeWithProof(
        uint256 commit,
        uint256 nullifier,
        address token,
        address to,
        uint256 amount,
        uint256 nonce,
        Proof memory proof
    ) external returns (bool success) {
        if (nullified[nullifier]) {
            revert Nullified();
        }
        nullified[nullifier] = true;

        bytes32 transferHash = getTransferHash(token, to, amount, nonce);
        if (!verifyProof(commit, nullifier, transferHash, proof)) {
            revert InvalidProof();
        }

        success = _execute(token, to, amount);
    }

    function executeWithRecovery(
        uint256 commit,
        uint256 saltHash,
        address token,
        address to,
        uint256 amount,
        RecoveryVerifier.Proof memory proof
    ) external returns (bool success) {
        if (!verifyRecoveryProof(commit, msg.sender, saltHash, proof)) {
            revert InvalidProof();
        }

        success = _execute(token, to, amount);
    }

    function domainSeparator() public view returns (bytes32 hash) {
        hash = keccak256(abi.encode(DOMAIN_TYPEHASH, block.chainid, this));
    }

    function getTransferHash(address token, address to, uint256 amount, uint256 nonce)
        public
        view
        returns (bytes32 hash)
    {
        hash = keccak256(
            abi.encodePacked(
                bytes2(0x1901), domainSeparator(), keccak256(abi.encode(TRANSFER_TYPEHASH, token, to, amount, nonce))
            )
        );
    }

    function getShadowling(uint256 commit) public view returns (address authority) {
        bytes32 authMessage = keccak256(abi.encodePacked(bytes4(0x05d78094), _SELF, bytes1(0x80)));
        (uint8 yParity, bytes32 r, bytes32 s) = getShadowlingDelegationSignature(commit);
        unchecked {
            authority = ecrecover(authMessage, yParity + 27, r, s);
        }
    }

    function getShadowlingDelegationSignature(uint256 commit)
        public
        pure
        returns (uint8 yParity, bytes32 r, bytes32 s)
    {
        yParity = 0;
        r = _R;
        s = bytes32(commit);
    }

    function verifyProof(uint256 commit, uint256 nullifier, bytes32 executionHash, Proof memory proof)
        public
        view
        returns (bool success)
    {
        success = _authorize(commit) && verifyTx(proof, [commit, nullifier, _fieldify(executionHash)]);
    }

    function verifyRecoveryProof(uint256 commit, address owner, uint256 saltHash, RecoveryVerifier.Proof memory proof)
        public
        view
        returns (bool success)
    {
        success = _authorize(commit) && RECOVERY.verifyTx(proof, [commit, uint256(uint160(owner)), saltHash]);
    }

    function verifyRegisterProof(
        uint256 commit,
        uint256 nullifier,
        bytes32 executionHash,
        uint256 saltHash,
        RegisterVerifier.Proof memory proof
    ) public view returns (bool success) {
        success =
            _authorize(commit) && REGISTER.verifyTx(proof, [commit, nullifier, _fieldify(executionHash), saltHash]);
    }

    function _authorize(uint256 commit) internal view returns (bool success) {
        success = address(this) == getShadowling(commit);
    }

    function _execute(address token, address to, uint256 amount) internal returns (bool success) {
        if (token == address(0)) {
            assembly ("memory-safe") {
                success := call(gas(), to, amount, 0, 0, 0, 0)
                if iszero(success) {
                    let ptr := mload(0x40)
                    returndatacopy(ptr, 0, returndatasize())
                    revert(ptr, returndatasize())
                }
            }
        } else {
            bytes memory callData = abi.encodeWithSignature("transfer(address,uint256)", to, amount);
            assembly ("memory-safe") {
                if iszero(call(gas(), token, 0, add(callData, 0x20), mload(callData), 0, 32)) {
                    let ptr := mload(0x40)
                    returndatacopy(ptr, 0, returndatasize())
                    revert(ptr, returndatasize())
                }
                switch returndatasize()
                case 0 { success := iszero(iszero(extcodesize(token))) }
                default { success := and(gt(returndatasize(), 31), eq(mload(0), 1)) }
            }
            require(success, TransferFailed());
        }
    }

    function _fieldify(bytes32 value) internal pure returns (uint256 field) {
        field = uint256(uint248(uint256(value)));
    }
}
