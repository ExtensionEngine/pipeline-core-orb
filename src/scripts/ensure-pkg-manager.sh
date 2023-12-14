#!/bin/bash

if [[ "$PKG_MANAGER" == "pnpm" ]]; then
  if ! pnpm --version | grep -q "^[0-9]"; then
    echo "Installing pnpm using Corepack"
    corepack enable
    corepack prepare pnpm@latest --activate
  fi

  echo "Setting ~/.pnpm-store as the store directory"
  pnpm config set store-dir ~/.pnpm-store
fi
