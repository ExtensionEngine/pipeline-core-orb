#!/bin/bash

NODE_VERSION_REGEX="v([0-9]+).([0-9]+).([0-9]+)"
NODE_VERSION=$(node -v)
MAJOR=""
MINOR=""

if [[ "${NODE_VERSION}" =~ ${NODE_VERSION_REGEX} ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"

  if [[ "${MAJOR}" -lt 16 || ("${MAJOR}" -eq 16 && "${MINOR}" -lt 20) ]]; then
    echo "At least Node.js v16.20 is required!"

    exit 1
  fi
fi
