import { Button, CardActions, Paper, Typography } from "@mui/material";
import { useCallback, useEffect, useState } from "react";
import { ethers, SignatureLike } from "ethers";
import { calculateCommit } from "../utils/proof";
import { SHADOWLING_ADDRESS } from "../utils/invoker";
import ShadowEntry from "./ShadowEntry";
import RecoveryDialog from "../transact/RecoveryDialog";
import Grid from "@mui/material/Unstable_Grid2/Grid2";

const FIXED_SIGNATURE = {
  yParity: 0 as const,
  r: ethers.toBeHex(BigInt(ethers.id("Shadowlings.r")) - BigInt(1), 32),
};
const CHAIN_ID = 1337;

export interface Shadow {
  address: string;
  salt: string;
}

export interface Props {
  owner: string;
  entropy: string;
}

const persistShadows = (owner: string, shadows: Array<Shadow>) => {
  localStorage.setItem(`${owner}_shadows`, JSON.stringify(shadows));
};

const loadPersistedShadows = (owner: string): Array<Shadow> => {
  return JSON.parse(localStorage.getItem(`${owner}_shadows`) || "[]");
};

export const recoverShadowlingAddress = (
  commit: string,
  invoker: string = SHADOWLING_ADDRESS,
): string => {
  return ethers.verifyAuthorization(
    { chainId: 0, address: invoker, nonce: 0 },
    { ...FIXED_SIGNATURE, s: ethers.toBeHex(commit, 32) },
  );
};

// keccak256(abi.encodePacked(uint8(0x04), block.chainid, uint256(0), uint256(uint160(address(this))), commit));
const createShadow = async (
  owner: string,
  entropy: string,
): Promise<Shadow> => {
  const salt = ethers.hexlify(ethers.randomBytes(31));
  const { commit } = await calculateCommit(owner, entropy, salt);
  const address = recoverShadowlingAddress(commit);
  return {
    address,
    salt,
  };
};

export default function ShadowList({ owner, entropy }: Props): JSX.Element {
  const [showRecoveryDialog, setShowRecoveryDialog] = useState(false);
  const [shadows, setShadows] = useState<Array<Shadow>>(
    loadPersistedShadows(owner),
  );

  const addShadow = useCallback(async () => {
    const shadows = loadPersistedShadows(owner);
    shadows.push(await createShadow(owner, entropy));
    persistShadows(owner, shadows);
    setShadows(shadows);
  }, [owner, entropy]);

  const removeShadow = useCallback(async (shadowId: string) => {
    const shadows = loadPersistedShadows(owner)
      .filter((shadow) => shadow.address != shadowId);
    persistShadows(owner, shadows);
    setShadows(shadows);
  }, [owner, entropy]);
  return (
    <Paper
      style={{ padding: "8px", maxWidth: "800px", margin: "0px auto" }}
      elevation={0}
    >
      <RecoveryDialog
        open={showRecoveryDialog}
        handleClose={() => setShowRecoveryDialog(false)}
      />
      <Typography>
        Shadows: <Button onClick={addShadow}>Add</Button>
        <Button onClick={() => setShowRecoveryDialog(true)}>Recover</Button>
      </Typography>
      <Grid container spacing={2}>
        {shadows.map((shadow) => (
          <Grid xs={6}>
            <ShadowEntry
              owner={owner}
              shadow={shadow}
              onRemove={removeShadow}
            />
          </Grid>
        ))}
      </Grid>
    </Paper>
  );
}
