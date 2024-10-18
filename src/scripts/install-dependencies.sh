#!/bin/bash

if [[ -n "${PARAM_STR_INSTALL_COMMAND}" ]]; then
  echo "Running custom install command"
  set -x
  eval "${PARAM_STR_INSTALL_COMMAND}"
  set +x
elif [[ "${CURRENT_PKG_MANAGER}" == "npm" ]]; then
  echo "Running npm clean install"
  npm ci
elif [[ "${CURRENT_PKG_MANAGER}" == "pnpm" ]]; then
  echo "Running pnpm install with frozen lockfile"
  pnpm i --frozen-lockfile
fi
