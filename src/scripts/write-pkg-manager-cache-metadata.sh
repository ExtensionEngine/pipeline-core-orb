#!/bin/bash

DEST_FILE="/tmp/node-cache-metadata"
PKG_MANAGER_VERSION=""

if [[ -z "${CURRENT_PKG_MANAGER}" ]]; then
  echo "Package manager was not resolved"
  echo "Cannot write package manager cache metadata without CURRENT_PKG_MANAGER"

  exit 1
fi

if [[ "${CURRENT_PKG_MANAGER}" != "npm" && "${CURRENT_PKG_MANAGER}" != "pnpm" ]]; then
  echo "Cannot write package manager cache metadata for unsupported package manager '${CURRENT_PKG_MANAGER}'"

  exit 1
fi

if ! PKG_MANAGER_VERSION=$("${CURRENT_PKG_MANAGER}" --version); then
  echo "Cannot write package manager cache metadata because ${CURRENT_PKG_MANAGER} version lookup failed"

  exit 1
fi

PKG_MANAGER_MAJOR="${PKG_MANAGER_VERSION%%.*}"

echo "Writing package manager cache metadata: ${CURRENT_PKG_MANAGER}@${PKG_MANAGER_MAJOR}"
printf 'package-manager=%s@%s\n' "${CURRENT_PKG_MANAGER}" "${PKG_MANAGER_MAJOR}" >>"${DEST_FILE}"
