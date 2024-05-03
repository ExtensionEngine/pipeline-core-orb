#!/bin/bash

if [[ -n "$INSTALL_CMD" ]]; then
  echo "Running custom install command:"
  eval "$INSTALL_CMD"
elif [[ "$CURRENT_PKG_MANAGER" == "npm" ]]; then
  npm ci
elif [[ "$CURRENT_PKG_MANAGER" == "pnpm" ]]; then
  pnpm i --frozen-lockfile
fi
