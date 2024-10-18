#!/bin/bash

if [[ -n "${PARAM_STR_INSTALL_COMMAND}" ]]; then
  echo "Running custom install command:"
  eval "${PARAM_STR_INSTALL_COMMAND}"
elif [[ "${CURRENT_PKG_MANAGER}" == "npm" ]]; then
  npm ci
elif [[ "${CURRENT_PKG_MANAGER}" == "pnpm" ]]; then
  pnpm i --frozen-lockfile
fi
