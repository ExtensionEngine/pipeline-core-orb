#!/bin/bash

SUDO="sudo"

if [[ $EUID == 0 ]]; then
  SUDO=""
fi

PKG_MANAGER_WITH_VERSION_REGEX="(npm|pnpm)@(([0-9]+.?){0,2}[0-9]+|[a-z]+-?([0-9]+)?)"
NAME="$PKG_MANAGER"
VERSION=""

if [[ "$PKG_MANAGER" =~ $PKG_MANAGER_WITH_VERSION_REGEX ]]; then
  NAME="${BASH_REMATCH[1]}"
  VERSION="${BASH_REMATCH[2]}"
fi

echo "export CURRENT_PKG_MANAGER='$NAME'" >> "$BASH_ENV"

if [[ "$NAME" == "npm" ]]; then
  if [[ -n "$VERSION" ]]; then
    $SUDO npm i -g npm@"$VERSION"
    echo "Required npm version: $VERSION"
    echo "Installed npm version: $(npm --version)"
  else
    echo "Detected npm version: $(npm --version)"
  fi

  exit 0
fi

if [[ "$NAME" == "pnpm" ]]; then
  if command -v pnpm > /dev/null 2>&1; then
    echo "Found pnpm installation, removing it"
    $SUDO rm -rf "$(pnpm store path)" > /dev/null 2>&1
    $SUDO rm -rf "$PNPM_HOME" > /dev/null 2>&1
    $SUDO npm rm -g pnpm > /dev/null 2>&1
  fi

  export COREPACK_DEFAULT_TO_LATEST=0
  $SUDO corepack enable pnpm

  PNPM_VERSION=$(npm view pnpm version)

  if [[ -n "$VERSION" ]]; then
    PNPM_VERSION="$VERSION"
  fi

  COREPACK_VERSION_REGEX="([0-9]+).([0-9]+)."
  COREPACK_VERSION=$(corepack -v)
  LEGACY_MODE=false

  if [[ "$COREPACK_VERSION" =~ $COREPACK_VERSION_REGEX ]]; then
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"

    if [[ "$MAJOR" -eq 0 && "$MINOR" -lt 20 ]]; then
      # Required for Node 16 support
      LEGACY_MODE=true
      echo "Using Corepack legacy mode"
    fi
  fi

  if "$LEGACY_MODE"; then
    corepack prepare pnpm@"$PNPM_VERSION" --activate
  else
    corepack install -g pnpm@"$PNPM_VERSION"
  fi

  echo "Required pnpm version: $PNPM_VERSION"
  echo "Installed pnpm version: $(pnpm --version)"

  echo "Setting ~/.pnpm-store as the store directory"
  pnpm config set store-dir ~/.pnpm-store

  exit 0
fi

echo "Failed to ensure package manager"
echo "Please specify supported package manager through parameter or environment"

exit 1
