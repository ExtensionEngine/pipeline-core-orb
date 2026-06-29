#!/bin/bash

PKG_MANAGER_REF="${PARAM_STR_PKG_MANAGER:-${DEFAULT_PKG_MANAGER}}"
PKG_MANAGER_REGEX="^(npm|pnpm)(@(([0-9]+\.?){0,2}[0-9]+|[a-z]+-?([0-9]+)?))?$"
NAME=""
VERSION=""

if [[ "${PKG_MANAGER_REF}" =~ ${PKG_MANAGER_REGEX} ]]; then
  NAME="${BASH_REMATCH[1]}"
  VERSION="${BASH_REMATCH[3]}"
fi

if [[ -z "${NAME}" ]]; then
  echo "Package manager '${PKG_MANAGER_REF}' is not supported"
  echo "Please specify supported package manager through the pkg_manager parameter or DEFAULT_PKG_MANAGER environment"

  exit 1
fi

echo "Resolved package manager: ${NAME}"

if [[ -n "${VERSION}" ]]; then
  echo "Resolved package manager version/tag: ${VERSION}"
fi

echo "export CURRENT_PKG_MANAGER='${NAME}'" >>"${BASH_ENV}"
echo "export CURRENT_PKG_MANAGER_VERSION='${VERSION}'" >>"${BASH_ENV}"
