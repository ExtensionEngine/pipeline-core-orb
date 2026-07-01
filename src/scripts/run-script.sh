#!/bin/bash

if [[ -z "${PARAM_STR_SCRIPT}" ]]; then
  echo "Cannot run package.json script because the script parameter is empty"

  exit 1
fi

echo "Running package.json script '${PARAM_STR_SCRIPT}' at ${PWD}"

CMD=()
SCRIPT_ARGS=()
RUN_OPTIONS=()

if [[ -n "${PARAM_STR_SCRIPT_ARGS}" ]]; then
  read -ra SCRIPT_ARGS <<<"${PARAM_STR_SCRIPT_ARGS}"
fi

if [[ -n "${PARAM_STR_RUN_OPTIONS}" ]]; then
  read -ra RUN_OPTIONS <<<"${PARAM_STR_RUN_OPTIONS}"
fi

if [[ "${CURRENT_PKG_MANAGER}" == "npm" ]]; then
  CMD=(npm run "${PARAM_STR_SCRIPT}")
  CMD+=("${RUN_OPTIONS[@]}")

  if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
    CMD+=(--)
    CMD+=("${SCRIPT_ARGS[@]}")
  fi
elif [[ "${CURRENT_PKG_MANAGER}" == "pnpm" ]]; then
  CMD=(pnpm)
  CMD+=("${RUN_OPTIONS[@]}")
  CMD+=(run "${PARAM_STR_SCRIPT}")
  CMD+=("${SCRIPT_ARGS[@]}")
else
  # This should not happen, but just to be on the safe side
  echo "Cannot run script with unsupported package manager '${CURRENT_PKG_MANAGER}'"

  exit 1
fi

echo 'Executing:'

set -x
"${CMD[@]}"
EXIT_STATUS=$?
set +x

exit "${EXIT_STATUS}"
