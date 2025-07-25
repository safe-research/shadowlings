import Dialog from "@mui/material/Dialog";
import DialogTitle from "@mui/material/DialogTitle";
import DialogContent from "@mui/material/DialogContent";
import DialogContentText from "@mui/material/DialogContentText";
import Card from "@mui/material/Card";
import CardActions from "@mui/material/CardActions";
import CardContent from "@mui/material/CardContent";
import TextField from "@mui/material/TextField";
import {
  Button,
  CardActionArea,
  CircularProgress,
  DialogActions,
} from "@mui/material";
import { encodeBase32 } from "geohashing";
import React, { useCallback, useEffect, useState } from "react";
import { ethers } from "ethers";
import { createRegisterData, createWithdrawData } from "../utils/proof";
import { globalBundler } from "../utils/userops";
import { queryRecoveryRegistrations } from "../utils/web3";

export interface Props {
  open: boolean;
  handleClose: () => void;
  shadowAddress: string;
  salt: string;
}

export default function RegisterDialog(
  { open, handleClose, shadowAddress, salt }: Props,
): JSX.Element {
  const [processing, setProcessing] = useState(false);
  const registerRecovery = useCallback(async () => {
    setProcessing(true);
    try {
      const owner = ethers.getAddress(localStorage.getItem("owner")!!);
      const entropy = localStorage.getItem("entropy")!!;
      // TODO: chech that entropy is set
      const registerData = await createRegisterData(
        shadowAddress,
        owner,
        entropy,
        salt,
      );

      console.log(registerData);
      console.log(
        await globalBundler.sendUserOperation(
          registerData.userOp,
          registerData.entrypoint,
        ),
      );
      handleClose();
    } catch (e) {
      console.error(e);
    } finally {
      setProcessing(false);
    }
  }, [shadowAddress, salt, handleClose, setProcessing]);

  return (
    <Dialog
      open={open}
      onClose={handleClose}
      aria-labelledby="alert-dialog-title"
      aria-describedby="alert-dialog-description"
    >
      <DialogTitle id="alert-dialog-title">
        {"Register Recovery"}
      </DialogTitle>
      <DialogContent style={{ padding: "8px" }}>
        Registering for recovery will submit a hash of the connection to the
        owner account onchain. With this it is possible to easily access the
        deposit address even in case the credentials are lost.
        <DialogActions>
          {!processing && (
            <Button
              size="small"
              onClick={() => registerRecovery()}
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
