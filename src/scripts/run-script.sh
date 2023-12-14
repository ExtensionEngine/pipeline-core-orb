#!/bin/bash

if [[ "$PKG_MANAGER" == "npm" ]]; then
  npm run "$SCRIPT"
elif [[ "$PKG_MANAGER" == "pnpm" ]]; then
  pnpm run "$SCRIPT"
fi
