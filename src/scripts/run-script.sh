#!/bin/bash

echo "Running package.json script at ${PWD}"

if [[ "${CURRENT_PKG_MANAGER}" == "npm" ]]; then
  eval npm run "${PARAM_STR_SCRIPT}"
elif [[ "${CURRENT_PKG_MANAGER}" == "pnpm" ]]; then
  eval pnpm run "${PARAM_STR_SCRIPT}"
else
  # This should not happen, but just to be on the safe side
  echo "Cannot run script with unsupported package manager '${CURRENT_PKG_MANAGER}'"

  exit 1
fi
