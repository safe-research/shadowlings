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

    function test_AnyCommitIsValid() public view {
        uint256 p = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        for (uint256 i = 0; i < 100; i++) {
            uint256 commit = uint256(keccak256(abi.encode(i))) % p;
            address shadowling = shadowlings.getShadowling(commit);

            assertNotEq(shadowling, address(0));
        }
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
        (uint8 yParity, bytes32 r, bytes32 s) = shadowlings.getShadowlingDelegationSignature(commit);
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
        nullifier = 0x093c6d9b3a569295b89e33e6e4f49b44050063ffa2ea0039e52b0bfc6b3b7035;
        executionHash = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee;

        proof.a = Pairing.G1Point(
            0x0af58fe57774255accf23f1b83432e280f0a9ac03fc5fa84fb74bf61866be20c,
            0x232d5781beddc97999033d8a1b34ff8b1718214c9c51ace149d88d9e24cc9532
        );
        proof.b = Pairing.G2Point(
            [
                0x0aa351a0aab4d8e1f2044852420c01d8190b071119110fb1a53df0a8bfe9743e,
                0x0a28f7bafcfca1e9255707b6fa7af4c5dee7860741a69aac4d28192c8ddc5a64
            ],
            [
                0x0ce7435890ad5fb22f96db6b0e5a3369e5ee094991dacb11ca2ceb83b11018d5,
                0x072adcf8cd9695e35d6a5aedaffd5bb6303660382df67231c51dc6d1a45cd809
            ]
        );
        proof.c = Pairing.G1Point(
            0x07b7e38dc1b4078e4989ec933e129d8921638da7df456f08d8ddeee57a23e07c,
            0x26603ac0986237dbb0e4015697e40d40909385cfe3972231126acec582b6a338
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
        nullifier = 0x093c6d9b3a569295b89e33e6e4f49b44050063ffa2ea0039e52b0bfc6b3b7035;
        executionHash = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee;
        saltHash = 0x0167d79660812409fa2f73c39d3b34cd1dd77b81f2e5b065c2411a7535f2f740;

        proof.a = RegisterPairing.G1Point(
            0x2f2440abb2c207c7e1d610b53947402760a12984f58a30400db9cb846bf9bb27,
            0x1de0a3ce3cb9a458998b3e16ad10e1264fb4f67dd600b29ccf5bab15dc909ddb
        );
        proof.b = RegisterPairing.G2Point(
            [
                0x1a7ab4931c488380eb20cd71096dcea5a665907b6c79b1ea32b34b7b5dd985a0,
                0x26a2e15a697ef433bd3ab1749d8ffdba495dbda5279b69acb5e4bb671cf67067
            ],
            [
                0x268e12cb2b8eb36cc39e597c6182183357d21c9d5862adc98ff7a57e554cbef7,
                0x02e3a4580638ef6b84717fe6191f2df611877f97cf5fde9079d061382e74944c
            ]
        );
        proof.c = RegisterPairing.G1Point(
            0x1d697af3ca9cebe2f9428ce1201701cd6188a8bbabf0e39681228c781168c1ef,
            0x2430ef330bc1cb01b16456fedabbc64f97469703e85dc76752e944da5e2d6205
        );
    }
}
