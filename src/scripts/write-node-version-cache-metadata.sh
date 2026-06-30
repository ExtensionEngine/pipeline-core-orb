#!/bin/bash

DEST_FILE="/tmp/node-version"
NODE_VERSION_REGEX="^v([0-9]+)\.([0-9]+)\.([0-9]+)$"
NODE_VERSION=$(node -v)
MAJOR=""

if [[ "${NODE_VERSION}" =~ ${NODE_VERSION_REGEX} ]]; then
  MAJOR="${BASH_REMATCH[1]}"
else
  echo "Could not parse Node.js version: ${NODE_VERSION}"
  echo "Cannot write Node.js major version cache metadata"

  exit 1
fi

echo "Writing Node.js major version cache metadata: ${MAJOR}"
echo "${MAJOR}" >|"${DEST_FILE}"
