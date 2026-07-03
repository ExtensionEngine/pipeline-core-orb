#!/bin/bash

if [[ -n "${PARAM_STR_INSTALL_COMMAND}" ]]; then
  echo "Running custom install command"

  exec bash -o pipefail -c "${PARAM_STR_INSTALL_COMMAND}"
elif [[ "${CURRENT_PKG_MANAGER}" == "npm" ]]; then
  echo "Running npm clean install"

  npm ci
elif [[ "${CURRENT_PKG_MANAGER}" == "pnpm" ]]; then
  echo "Running pnpm install with frozen lockfile"

  pnpm i --frozen-lockfile
else
  # This should not happen, but just to be on the safe side
  echo "Cannot install dependencies with unsupported package manager '${CURRENT_PKG_MANAGER}'"

  exit 1
fi
