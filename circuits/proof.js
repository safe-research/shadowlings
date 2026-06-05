import { promises as fs } from "fs";
import { initialize } from "zokrates-js";

import { buildMimcHasher, fromHex, toFieldElement } from "./util.js";

const owner = "0x1111111111111111111111111111111111111111";
const entropy = "0x5afe";
const salt = "0x01020304";
const pepper = "0x2a";
const executionHash =
  "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee";

async function load(name) {
  const artifacts = JSON.parse(
    await fs.readFile(
      `./app/src/config/${name}/artifacts.json`,
      "utf-8",
    ),
  );
  const keypair = JSON.parse(
    await fs.readFile(
      `./app/src/config/${name}/keypair.json`,
      "utf-8",
    ),
  );
  return {
    artifacts: { ...artifacts, program: fromHex(artifacts.program) },
    keypair: { ...keypair, pk: fromHex(keypair.pk) },
  };
}

function proove(zokrates, { artifacts, keypair }, inputs) {
  const { witness } = zokrates.computeWitness(
    artifacts,
    inputs.map(toFieldElement),
  );
  const proof = zokrates.generateProof(
    artifacts.program,
    witness,
    keypair.pk,
  );

  if (!zokrates.verify(keypair.vk, proof)) {
    throw new Error("error locally verifying proof");
  }

  console.log(proof.proof);
  console.log({ inputs: proof.inputs });
}

async function main() {
  const zokrates = await initialize();
  const mimc = await buildMimcHasher();

  const circuits = {
    main: await load("main"),
    recovery: await load("recovery"),
    register: await load("register"),
  };

  const ownerHash = mimc(owner, entropy);
  const saltHash = mimc(salt, pepper);
  const commitHash = mimc(ownerHash, saltHash);
  const nullifierHash = mimc(executionHash, salt);

  console.log("### MAIN ###");
  proove(zokrates, circuits.main, [
    commitHash,
    nullifierHash,
    executionHash,
    ownerHash,
    salt,
  ]);

  console.log("### RECOVERY ###");
  proove(zokrates, circuits.recovery, [
    commitHash,
    owner,
    saltHash,
    entropy,
  ]);

  console.log("### REGISTER ###");
  proove(zokrates, circuits.register, [
    commitHash,
    nullifierHash,
    executionHash,
    saltHash,
    ownerHash,
    salt,
  ]);
}

main().catch((err) => console.error(err));
