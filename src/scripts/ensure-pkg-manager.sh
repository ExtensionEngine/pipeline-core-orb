#!/bin/bash

if [[ "$PKG_MANAGER" == "pnpm" ]]; then
  if ! pnpm --version | grep -E "^([8-9]|[1-9][0-9]{1,})\."; then
    echo "Appropriate version of pnpm not found, installing latest"
    corepack enable || sudo corepack enable
    corepack prepare pnpm@latest --activate
  fi

  echo "Setting ~/.pnpm-store as the store directory"
  pnpm config set store-dir ~/.pnpm-store
fi
