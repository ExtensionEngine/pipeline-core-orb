#!/bin/bash

DEST_FILE="/tmp/node-lockfile"

if [ -f "package-lock.json" ] && [[ "${CURRENT_PKG_MANAGER}" == "npm" ]]; then
  echo "Found package-lock.json, assuming lockfile"

  cp package-lock.json "${DEST_FILE}"

  exit 0
elif [ -f "pnpm-lock.yaml" ] && [[ "${CURRENT_PKG_MANAGER}" == "pnpm" ]]; then
  echo "Found pnpm-lock.ymal, assuming lockfile"

  cp pnpm-lock.yaml "${DEST_FILE}"

  exit 0
fi

echo "The lockfile not found!"
echo "Current package manager: ${CURRENT_PKG_MANAGER}"

exit 1
