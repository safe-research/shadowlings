#!/usr/bin/env bash

MNEMONIC="$(dirname $0)/bundler/data/mnemonic.txt"
VALUE="test test test test test test test test test test test junk"

if ! [[ -e "$MNEMONIC" ]]; then
  echo "Writing default relayer mnemonic to '$MNEMONIC':"
  echo "    $VALUE"
  echo "Please add your own mnemonic if connecting to a public network."
  echo "$VALUE" >"$MNEMONIC"
fi
