#!/bin/bash

if [[ "$PKG_MANAGER" == "npm" ]]; then
  npm ci
elif [[ "$PKG_MANAGER" == "pnpm" ]]; then
  pnpm i --frozen-lockfile
fi
