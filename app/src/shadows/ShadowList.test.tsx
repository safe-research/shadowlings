import { ethers } from "ethers";
import { recoverShadowlingAddress } from "./ShadowList";
import { calculateCommit } from "../utils/proof";

test("Recover expected address", () => {
  expect(
    recoverShadowlingAddress(
      "0x2171de7d497df3423fb6f2a86aaf6548c337100ff106a1803c30fb84796e63af",
      "0xa82B48085abF81e6Cbe3Aa9D9e33B43b43977adD",
    ),
  ).toBe("0xDf8F36B9b828e69e160733485088c0C31DfB4132");
});

test("Calculate commit", async () => {
  const owner = "0x1111111111111111111111111111111111111111";
  const entropy = "0x5afe";
  const salt = "0x01020304";
  const commit = await calculateCommit(owner, entropy, salt);
  expect(commit).toBe(
    "0x153c333c4856f04f11c983484a8fbcd2705b4460498f55b4771cd09af3c306ab",
  );
});
