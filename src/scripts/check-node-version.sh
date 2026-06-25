#!/bin/bash

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js not detected"
  echo "Execution environment with Node.js pre-installed is required!"

  exit 1
fi

NODE_VERSION_REGEX="v([0-9]+).([0-9]+).([0-9]+)"
NODE_VERSION=$(node -v)
MAJOR=""
MINOR=""

if [[ "${NODE_VERSION}" =~ ${NODE_VERSION_REGEX} ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"

  if [[ "${MAJOR}" -lt 18 || ("${MAJOR}" -eq 18 && "${MINOR}" -lt 20) ]]; then
    echo "At least Node.js v18.20 is required!"

    exit 1
  fi
fi
