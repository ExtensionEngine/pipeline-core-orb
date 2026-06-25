#!/bin/bash

DEST_FILE="/tmp/node-pkg-manager"

if [[ -z "${CURRENT_PKG_MANAGER}" ]]; then
  echo "Package manager was not resolved"
  echo "Cannot write package manager cache metadata without CURRENT_PKG_MANAGER"

  exit 1
fi

if [[ "${CURRENT_PKG_MANAGER}" != "npm" && "${CURRENT_PKG_MANAGER}" != "pnpm" ]]; then
  echo "Cannot write package manager cache metadata for unsupported package manager '${CURRENT_PKG_MANAGER}'"

  exit 1
fi

echo "Writing package manager cache metadata: ${CURRENT_PKG_MANAGER}"
echo "${CURRENT_PKG_MANAGER}" >|"${DEST_FILE}"
