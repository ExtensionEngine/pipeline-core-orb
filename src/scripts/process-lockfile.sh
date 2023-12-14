#!/bin/bash

DEST_FILE="/tmp/node-project-lock"

if [ -f "package-lock.json" ]; then
  echo "Found package-lock.json, assuming lockfile"
  cp package-lock.json $DEST_FILE
elif [ -f "pnpm-lock.yaml" ]; then
  echo "Found pnpm-lock.ymal, assuming lockfile"
  cp pnpm-lock.yaml $DEST_FILE
fi
