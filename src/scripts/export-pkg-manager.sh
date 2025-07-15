#!/bin/bash

PARAM_STR_REF=$(circleci env subst "${PARAM_STR_REF}")
PKG_MANAGER_REGEX="^(npm|pnpm)(@(([0-9]+.?){0,2}[0-9]+|[a-z]+-?([0-9]+)?))?$"
NAME=""
VERSION=""

if [[ "${PARAM_STR_REF}" =~ ${PKG_MANAGER_REGEX} ]]; then
  NAME="${BASH_REMATCH[1]}"
  VERSION="${BASH_REMATCH[3]}"
fi

if [[ -z "${NAME}" ]]; then
  echo "Package manager '${NAME}' is not supported"
  echo "Please specify supported package manager through parameter or environment"

  exit 1
fi

echo "export CURRENT_PKG_MANAGER='${NAME}'" >>"${BASH_ENV}"
echo "export CURRENT_PKG_MANAGER_VERSION='${VERSION}'" >>"${BASH_ENV}"
