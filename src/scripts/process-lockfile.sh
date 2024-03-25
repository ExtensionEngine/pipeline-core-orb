#!/bin/bash

DEST_FILE="/tmp/node-lockfile"

if [ -f "package-lock.json" ] && [[ "$PKG_MANAGER" == "npm" ]]; then
  echo "Found package-lock.json, assuming lockfile"
  cp package-lock.json "$DEST_FILE"
elif [ -f "pnpm-lock.yaml" ] && [[ "$PKG_MANAGER" == "pnpm" ]]; then
  echo "Found pnpm-lock.ymal, assuming lockfile"
  cp pnpm-lock.yaml "$DEST_FILE"
fi
