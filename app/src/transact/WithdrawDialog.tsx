import Dialog from "@mui/material/Dialog";
import DialogTitle from "@mui/material/DialogTitle";
import DialogContent from "@mui/material/DialogContent";
import TextField from "@mui/material/TextField";
import { Button, CircularProgress, DialogActions } from "@mui/material";
import { useCallback, useState } from "react";
import { ethers } from "ethers";
import { createWithdrawData } from "../utils/proof";
import { globalBundler } from "../utils/userops";
import { Token } from "../utils/tokens";

export interface Props {
  open: boolean;
  handleClose: () => void;
  shadowAddress: string;
  salt: string;
  token: Token | undefined;
  maxAmount: string | undefined;
}

export default function WithdrawDialog(
  { open, handleClose, shadowAddress, salt, token }: Props,
): JSX.Element {
  const [processing, setProcessing] = useState(false);
  const [target, setTarget] = useState("");
  const [amount, setAmount] = useState("");

  const generateProof = useCallback(async (target: string, amount: string) => {
    setProcessing(true);
    try {
      const owner = ethers.getAddress(localStorage.getItem("owner")!!);
      const entropy = localStorage.getItem("entropy")!!;
      // TODO: chech that entropy is set
      const targetAddress = ethers.getAddress(target);
      const amountAtoms = ethers.parseUnits(amount, token?.decimals);
      const withdrawData = await createWithdrawData(
        shadowAddress,
        owner,
        entropy,
        salt,
        token?.address || ethers.ZeroAddress,
        targetAddress,
        amountAtoms,
      );

      console.log(withdrawData);
      console.log(
        await globalBundler.sendUserOperation(
          withdrawData.userOp,
          withdrawData.entrypoint,
        ),
      );
      //setTarget("")
      //setAmount("")
      handleClose();
    } catch (e) {
      console.error(e);
    } finally {
      setProcessing(false);
    }
  }, [
    shadowAddress,
    salt,
    token,
    handleClose,
    setTarget,
    setAmount,
    setProcessing,
  ]);

  return (
    <Dialog
      open={open}
      onClose={handleClose}
      aria-labelledby="alert-dialog-title"
      aria-describedby="alert-dialog-description"
    >
      <DialogTitle id="alert-dialog-title">
        {`Withdraw ${token?.name || "Ether"}`}
      </DialogTitle>
      <DialogContent style={{ padding: "8px" }}>
        <TextField
          label="Target Address"
          variant="standard"
          value={target}
          onChange={(e) => setTarget(e.target.value)}
          style={{ margin: "8px" }}
        />
        <TextField
          label="Amount"
          variant="standard"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          style={{ margin: "8px" }}
        />
        <DialogActions>
          {!processing && (
            <Button
              size="small"
              onClick={() => generateProof(target, amount)}
            >
              Submit
            </Button>
          )}
          {processing && <CircularProgress size={24} />}
        </DialogActions>
      </DialogContent>
    </Dialog>
  );
}
