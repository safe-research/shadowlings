import { ethers } from "ethers";
import mainArtifactJson from "../config/main/artifacts.json";
import mainKeypairJson from "../config/main/keypair.json";
import registerArtifactJson from "../config/register/artifacts.json";
import registerKeypairJson from "../config/register/keypair.json";
import recoveryArtifactJson from "../config/recovery/artifacts.json";
import recoveryKeypairJson from "../config/recovery/keypair.json";
import { Abi, CompilationArtifacts, initialize, Proof } from "zokrates-js";
import { buildMimcSponge, MimcSponge } from "circomlibjs";
import {
  buildUserOps,
  calculateUserOpHash,
  entrypoint,
  SignedUserOperation,
} from "./userops";
import { encodeExecute, encodeRegister } from "./invoker";

var mimc: MimcSponge | undefined;

const globalMimc = async (): Promise<MimcSponge> => {
  if (!mimc) mimc = await buildMimcSponge();
  return mimc;
};

export const hash = async (...parts: string[]): Promise<string> => {
  const mimc = await globalMimc();
  return `0x${mimc.F.toString(mimc.multiHash(parts), 16).padStart(64, "0")}`;
};

export function fromHex(a: string) {
  return Buffer.from(a.replace(/^0x/, ""), "hex");
}

export function fieldify(value: string) {
  return ethers.toBeHex(
    BigInt(value) &
      BigInt(
        "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
      ),
  );
}

export const calculateCommit = async (
  owner: string,
  entropy: string,
  salt: string,
  pepper: string = "0x2a",
): Promise<{
  ownerHash: string;
  saltHash: string;
  commit: string;
}> => {
  const ownerHash = await hash(
    owner,
    ethers.hexlify(ethers.toUtf8Bytes(entropy)),
  );
  const saltHash = await hash(salt, pepper);
  return {
    ownerHash,
    saltHash,
    commit: await hash(ownerHash, saltHash),
  };
};

interface PersistedArtifact {
  program: string;
  abi: Abi;
}

export function toFieldElement(x: string) {
  return BigInt(x).toString();
}

const loadMainProvingKey = (): Uint8Array => {
  return ethers.getBytes(mainKeypairJson.pk);
};

const loadPersistedMainArtifacts = (): PersistedArtifact => {
  return mainArtifactJson as any;
};

const loadMainArtifact = (): CompilationArtifacts => {
  const persisted = loadPersistedMainArtifacts();
  return {
    program: fromHex(persisted.program),
    abi: persisted.abi,
  };
};

export const createWithdrawData = async (
  shadow: string,
  owner: string,
  entropy: string,
  salt: string,
  token: string,
  target: string,
  amount: bigint,
): Promise<{
  entrypoint: string;
  commit: string;
  nullifier: string;
  proof: Proof;
  userOp: SignedUserOperation;
}> => {
  const zok = await initialize();
  const provingKey = loadMainProvingKey();
  const artifact = loadMainArtifact();
  const { saltHash, ownerHash, commit } = await calculateCommit(
    owner,
    entropy,
    salt,
  );
  console.log({ entropy });
  console.log({ commit });
  const calldata = encodeExecute(token, target, amount);
  const ep = await entrypoint();
  const userOp = await buildUserOps(shadow, commit, calldata);
  const userOpHash = await calculateUserOpHash(userOp);
  const executionHash = fieldify(userOpHash);
  const nullifier = await hash(executionHash, saltHash);
  const { witness } = zok.computeWitness(
    artifact,
    [commit, nullifier, executionHash, ownerHash, salt].map(toFieldElement),
  );
  const proof = zok.generateProof(artifact.program, witness, provingKey);
  console.log(proof);
  return {
    entrypoint: await ep.getAddress(),
    commit,
    nullifier,
    proof,
    userOp: {
      ...userOp,
      signature: buildSignature(commit, nullifier, proof),
    },
  };
};

const loadRegisterProvingKey = (): Uint8Array => {
  return ethers.getBytes(registerKeypairJson.pk);
};
const loadPersistedRegisterArtifacts = (): PersistedArtifact => {
  return registerArtifactJson as any;
};

const loadRegisterArtifact = (): CompilationArtifacts => {
  const persisted = loadPersistedRegisterArtifacts();
  return {
    program: fromHex(persisted.program),
    abi: persisted.abi,
  };
};

export const createRegisterData = async (
  shadow: string,
  owner: string,
  entropy: string,
  salt: string,
): Promise<{
  entrypoint: string;
  commit: string;
  nullifier: string;
  proof: Proof;
  userOp: SignedUserOperation;
}> => {
  const zok = await initialize();
  const provingKey = loadRegisterProvingKey();
  const artifact = loadRegisterArtifact();
  const { saltHash, ownerHash, commit } = await calculateCommit(
    owner,
    entropy,
    salt,
  );
  console.log({ entropy });
  console.log({ commit });
  const calldata = encodeRegister(saltHash);
  // TODO refactor
  const ep = await entrypoint();
  const userOp = await buildUserOps(shadow, commit, calldata);
  const userOpHash = await calculateUserOpHash(userOp);
  const executionHash = fieldify(userOpHash);
  const nullifier = await hash(executionHash, saltHash);
  const { witness } = zok.computeWitness(
    artifact,
    [commit, nullifier, executionHash, saltHash, ownerHash, salt].map(
      toFieldElement,
    ),
  );
  const proof = zok.generateProof(artifact.program, witness, provingKey);
  console.log(proof);
  return {
    entrypoint: await ep.getAddress(),
    commit,
    nullifier,
    proof,
    userOp: {
      ...userOp,
      signature: buildSignature(commit, nullifier, proof),
    },
  };
};

const loadRecoveryProvingKey = (): Uint8Array => {
  return ethers.getBytes(recoveryKeypairJson.pk);
};
const loadPersistedRecoveryArtifacts = (): PersistedArtifact => {
  return recoveryArtifactJson as any;
};

const loadRecoveryArtifact = (): CompilationArtifacts => {
  const persisted = loadPersistedRecoveryArtifacts();
  return {
    program: fromHex(persisted.program),
    abi: persisted.abi,
  };
};

export const createRecoveryData = async (
  owner: string,
  entropy: string,
  saltHash: string,
): Promise<{
  commit: string;
  proof: Proof;
}> => {
  const zok = await initialize();
  const provingKey = loadRecoveryProvingKey();
  const artifact = loadRecoveryArtifact();
  const encodedEntropy = ethers.hexlify(ethers.toUtf8Bytes(entropy));

  const ownerHash = await hash(owner, encodedEntropy);
  const commit = await hash(ownerHash, saltHash);
  const { witness } = zok.computeWitness(
    artifact,
    [commit, owner, saltHash, encodedEntropy].map(toFieldElement),
  );
  const proof = zok.generateProof(artifact.program, witness, provingKey);
  console.log(proof);
  return {
    commit,
    proof,
  };
};

const buildSignature = (commit: string, nullifier: string, proof: Proof) => {
  const p: any = proof.proof;
  return ethers.AbiCoder.defaultAbiCoder().encode(
    ["uint256", "uint256", "tuple(uint256[2], uint256[2][2], uint256[2])"],
    [commit, nullifier, [p.a, p.b, p.c]],
  );
};
