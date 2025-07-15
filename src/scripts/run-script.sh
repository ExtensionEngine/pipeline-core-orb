#!/bin/bash

echo "Running custom script from package.json at ${PWD}"

PKG_MANAGER=$(circleci env subst "${PARAM_STR_PKG_MANAGER}")
PKG_MANAGER_REGEX="^(npm|pnpm)(@.+)?$"

if [[ "${PKG_MANAGER}" =~ ${PKG_MANAGER_REGEX} ]]; then
  PKG_MANAGER="${BASH_REMATCH[1]}"
else
  echo "Cannot run script with unsupported package manager '${PKG_MANAGER}'"

  exit 1
fi

set -x
eval "${PKG_MANAGER}" run "${PARAM_STR_SCRIPT}"
set +x
