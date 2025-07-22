// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.13;

import {PackedUserOperation, UserOperationLib} from "account-abstraction/core/UserOperationLib.sol";
import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {ShadowToken} from "../src/ShadowToken.sol";
import {Shadowlings, Verifier, RecoveryVerifier, RegisterVerifier} from "../src/Shadowlings.sol";
import {Pairing} from "../src/verifiers/main/Verifier.sol";
import {Pairing as RecoveryPairing} from "../src/verifiers/recovery/Verifier.sol";
import {Pairing as RegisterPairing} from "../src/verifiers/register/Verifier.sol";

contract ShadowlingsTest is Test {
    address entryPoint = vm.addr(uint256(keccak256("secret")));
    Shadowlings shadowlings = new Shadowlings(entryPoint);
    ShadowToken shadowToken = new ShadowToken();

    function setUp() public {}

    function test_Delegation() public {
        uint256 commit = uint256(uint248(uint256(keccak256("commit"))));
        address shadowling = shadowlings.getShadowling(commit);

        assertEq(shadowling.code.length, 0);

        _delegate(commit);

        assertNotEq(shadowling.code.length, 0);
    }

    function test_Execute() public {
        uint256 commit = uint256(uint248(uint256(keccak256("commit"))));
        address token = address(0);
        address to = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        uint256 amount = 1 ether;

        Shadowlings shadowling = _getAndDelegateShadowling(commit);
        vm.deal(address(shadowling), amount);

        assertEq(to.balance, 0);
        assertEq(address(shadowling).balance, 1 ether);

        vm.prank(entryPoint);
        shadowling.execute(token, to, amount);

        assertEq(to.balance, 1 ether);
        assertEq(address(shadowling).balance, 0);
    }

    function test_ExecuteToken() public {
        uint256 commit = uint256(uint248(uint256(keccak256("commit"))));
        address token = address(shadowToken);
        address to = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        uint256 amount = 1 ether;

        Shadowlings shadowling = _getAndDelegateShadowling(commit);
        shadowToken.mint(address(shadowling), amount);

        assertEq(shadowToken.balanceOf(to), 0);
        assertEq(shadowToken.balanceOf(address(shadowling)), 1 ether);

        vm.prank(entryPoint);
        shadowling.execute(token, to, amount);

        assertEq(shadowToken.balanceOf(to), 1 ether);
        assertEq(shadowToken.balanceOf(address(shadowling)), 0);
    }

    function test_UserOperation() public {
        (uint256 commit, uint256 nullifier, bytes32 executionHash, Verifier.Proof memory proof) = _sampleProof();

        address token = address(0);
        address to = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        uint256 amount = 1 ether;

        Shadowlings shadowling = _getAndDelegateShadowling(commit);
        vm.deal(address(shadowling), 2 ether);

        bytes memory callData = abi.encodeCall(shadowling.execute, (token, to, amount));
        bytes memory signature = abi.encode(commit, nullifier, proof);

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(shadowling),
            nonce: 0,
            initCode: "",
            callData: callData,
            accountGasLimits: 0,
            preVerificationGas: 0,
            gasFees: 0,
            paymasterAndData: "",
            signature: signature
        });
        bytes32 userOpHash = executionHash;

        assertEq(entryPoint.balance, 0);
        assertEq(to.balance, 0);
        assertEq(address(shadowling).balance, 2 ether);

        vm.startPrank(entryPoint);
        require(shadowling.validateUserOp(userOp, userOpHash, 0.1 ether) == 0);
        shadowling.execute(token, to, amount);

        assertEq(entryPoint.balance, 0.1 ether);
        assertEq(to.balance, 1 ether);
        assertEq(address(shadowling).balance, 0.9 ether);
    }

    function test_RegisterSaltNonce() public {
        (
            uint256 commit,
            uint256 nullifier,
            bytes32 executionHash,
            uint256 saltHash,
            RegisterVerifier.Proof memory proof
        ) = _sampleRegisterProof();

        Shadowlings shadowling = _getAndDelegateShadowling(commit);

        bytes memory callData = abi.encodeCall(shadowlings.register, (saltHash));
        bytes memory signature = abi.encode(commit, nullifier, proof);

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(shadowling),
            nonce: 0,
            initCode: "",
            callData: callData,
            accountGasLimits: 0,
            preVerificationGas: 0,
            gasFees: 0,
            paymasterAndData: "",
            signature: signature
        });
        bytes32 userOpHash = executionHash;

        vm.startPrank(entryPoint);
        require(shadowling.validateUserOp(userOp, userOpHash, 0) == 0);
        shadowling.register(saltHash);
    }

    function test_VerifyProof() public {
        (uint256 commit, uint256 nullifier, bytes32 executionHash, Verifier.Proof memory proof) = _sampleProof();
        Shadowlings shadowling = _getAndDelegateShadowling(commit);

        bool success = shadowling.verifyProof(commit, nullifier, executionHash, proof);

        assertTrue(success);
    }

    function test_VerifyRecoveryProof() public {
        (uint256 commit, address owner, uint256 saltHash, RecoveryVerifier.Proof memory proof) = _sampleRecoveryProof();
        Shadowlings shadowling = _getAndDelegateShadowling(commit);

        bool success = shadowling.verifyRecoveryProof(commit, owner, saltHash, proof);

        assertTrue(success);
    }

    function test_VerifyRegisterProof() public {
        (
            uint256 commit,
            uint256 nullifier,
            bytes32 executionHash,
            uint256 saltHash,
            RegisterVerifier.Proof memory proof
        ) = _sampleRegisterProof();
        Shadowlings shadowling = _getAndDelegateShadowling(commit);

        bool success = shadowling.verifyRegisterProof(commit, nullifier, executionHash, saltHash, proof);

        assertTrue(success);
    }

    function test_ExecuteWithRecovery() public {
        (uint256 commit, address owner, uint256 saltHash, RecoveryVerifier.Proof memory proof) = _sampleRecoveryProof();

        address token = address(0);
        address to = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        uint256 amount = 1 ether;

        Shadowlings shadowling = _getAndDelegateShadowling(commit);
        vm.deal(address(shadowling), amount);

        assertEq(to.balance, 0);
        assertEq(address(shadowling).balance, 1 ether);

        vm.prank(owner);
        bool success = shadowling.executeWithRecovery(commit, saltHash, token, to, amount, proof);

        assertEq(to.balance, 1 ether);
        assertEq(address(shadowling).balance, 0);
        assertTrue(success);
    }

    function _delegate(uint256 commit) internal {
        (bytes32 r, bytes32 s, uint8 yParity) = shadowlings.getShadowlingDelegationSignature(commit);
        VmSafe.SignedDelegation memory delegation =
            VmSafe.SignedDelegation({v: yParity, r: r, s: s, nonce: 0, implementation: address(shadowlings)});

        uint256 chainId = block.chainid;
        vm.chainId(0);
        vm.attachDelegation(delegation);
        vm.chainId(chainId);
    }

    function _getAndDelegateShadowling(uint256 commit) internal returns (Shadowlings shadowling) {
        _delegate(commit);
        shadowling = Shadowlings(payable(shadowlings.getShadowling(commit)));
    }

    function _sampleProof()
        internal
        pure
        returns (uint256 commit, uint256 nullifier, bytes32 executionHash, Verifier.Proof memory proof)
    {
        commit = 0x153c333c4856f04f11c983484a8fbcd2705b4460498f55b4771cd09af3c306ab;
        nullifier = 0x05476bcdcaba1d11916a4f3618d499f9b6c53506cb825926f25ea37e0627cc0d;
        executionHash = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee;

        proof.a = Pairing.G1Point(
            0x156519e7174f3919963da97190bef3af71ab77c206741e93fc60ea1c401dbb3e,
            0x23d332a33ca334ba07ff9d8b1155f8862d2879022027971af44780a89d3b6bce
        );
        proof.b = Pairing.G2Point(
            [
                0x22f9a4e7dba2f6a77492f0388123d0a2c8054cae2115fc80db37f9c4209f3793,
                0x1df55020ef2c3abbc16338c6a400b1a892754f0d43e2a3677798a74ed61a73c1
            ],
            [
                0x2e715839bc1231c349ab7d2c77b9db4ba17046b10423fb9c4ad496f0de2a44d3,
                0x1a3cf8fc4b89f194107ea4e3e5de84a2867a7f9aff28fc48c3fd12dbcbb323f8
            ]
        );
        proof.c = Pairing.G1Point(
            0x145d4046b3af25fed85ee13bc51738e7cf7667468171315b45ff6f678a5d8a36,
            0x18eb28b2492cbe68eb115c9a501de2e987cb37e0477cae455702fe0b40f8651e
        );
    }

    function _sampleRecoveryProof()
        internal
        pure
        returns (uint256 commit, address owner, uint256 saltHash, RecoveryVerifier.Proof memory proof)
    {
        commit = 0x153c333c4856f04f11c983484a8fbcd2705b4460498f55b4771cd09af3c306ab;
        owner = 0x1111111111111111111111111111111111111111;
        saltHash = 0x0167d79660812409fa2f73c39d3b34cd1dd77b81f2e5b065c2411a7535f2f740;

        proof.a = RecoveryPairing.G1Point(
            0x123989bb962477e9dcd18b0e1f2861d3581c3f31f2824913df52056c18f4ad21,
            0x2ca547619edbc59a8d5a2f6a8fde74e70f765bbbfdf620e6a3fd8e703c125dee
        );
        proof.b = RecoveryPairing.G2Point(
            [
                0x103bff4b25af8e9b1da824ed2a05475e3787b6ab289c53927a040ef84622acce,
                0x295bc4bba75f6f485b1a769aecf1f29edfe44e7acaa3f17e13c0ef6b8caca654
            ],
            [
                0x2b8ad21fd1ad49226c8b35dee87e85f4f9e5bc2304e19731b9e005c83051b877,
                0x180f9b084978e3dec03240a867a9b6a376a03e91c0c66cea401df876c977f7bb
            ]
        );
        proof.c = RecoveryPairing.G1Point(
            0x0b4d4fb90134e330ff21ba7f620c500a99d5a167e2952be2ec732006cac4a8d4,
            0x24b613acc40113dd9a637c4998f32df956555e38a92a834cce03003a662bd163
        );
    }

    function _sampleRegisterProof()
        internal
        pure
        returns (
            uint256 commit,
            uint256 nullifier,
            bytes32 executionHash,
            uint256 saltHash,
            RegisterVerifier.Proof memory proof
        )
    {
        commit = 0x153c333c4856f04f11c983484a8fbcd2705b4460498f55b4771cd09af3c306ab;
        nullifier = 0x05476bcdcaba1d11916a4f3618d499f9b6c53506cb825926f25ea37e0627cc0d;
        executionHash = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee;
        saltHash = 0x0167d79660812409fa2f73c39d3b34cd1dd77b81f2e5b065c2411a7535f2f740;

        proof.a = RegisterPairing.G1Point(
            0x1320e03c3783d157a30bbec4f9db2a4761bc4dc3b88ba781e8c679f2b24d20fc,
            0x3034ce8546ce619ff015130eb67a08a59a81dc40431c6964fd620b9dbba96428
        );
        proof.b = RegisterPairing.G2Point(
            [
                0x11f26057be5b4f6377b2a87b25841139c2c9dc038c06cad65050d3368de375cf,
                0x2aeb06192d5372cee77b0d85a78c92d8c1b4cb043c9d89f284b2902a56a7d2ee
            ],
            [
                0x25e3b6d4e55be31dba513f26462078428c67c73041e3cb696c17b5b407e7fe2d,
                0x138357274e7c0caf8d9314ec6d0b963c80be63a10784efae8722565c9f395fbf
            ]
        );
        proof.c = RegisterPairing.G1Point(
            0x0f5fc53e0fe1e111549d7d333772909805fdadae5b109a6e96e50d1dd6655385,
            0x1c36a3924a9aa3a809ec8f0c484cb6d608d7513759855616a3a43c76ccbf475c
        );
    }
}
