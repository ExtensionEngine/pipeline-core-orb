#!/bin/bash

PARAM_STR_REF=$(circleci env subst "${PARAM_STR_REF}")
PKG_MANAGER_WITH_VERSION_REGEX="(npm|pnpm)@(([0-9]+.?){0,2}[0-9]+|[a-z]+-?([0-9]+)?)"
NAME="${PARAM_STR_REF}"
VERSION=""
SUDO=""

check_instalation () {
  local installed_version
  local required_version
  local tag_regex
  local tag_mapping

  installed_version=$(eval "$1" --version)
  required_version="$2"
  tag_regex=$(eval echo "$2":)
  tag_mapping=$(eval npm dist-tag ls "$1" | grep "${tag_regex}" || true)

  if [[ -n "${tag_mapping}" ]]; then
    required_version=$(echo "${tag_mapping}" | awk '{print $2}')
  fi

  echo "Installed $1 version: ${installed_version}"
  echo "Required $1 version: ${required_version}"

  if [[ "${installed_version}" != "${required_version}" ]]; then
    echo "Failed to install $1 '${required_version}'"

    exit 2
  fi
}

if [[ "${PARAM_STR_REF}" =~ ${PKG_MANAGER_WITH_VERSION_REGEX} ]]; then
  NAME="${BASH_REMATCH[1]}"
  VERSION="${BASH_REMATCH[2]}"
fi

echo "export CURRENT_PKG_MANAGER='${NAME}'" >> "${BASH_ENV}"
echo "Starting to ensure ${NAME} is set for usage"

if [[ ${EUID} -ne 0 ]]; then
  echo "Using sudo privileges to finish the process"

  SUDO="sudo"
fi

if [[ "${NAME}" == "npm" ]]; then
  if [[ -n "${VERSION}" ]]; then
    ${SUDO} npm i -g npm@"${VERSION}"
    check_instalation "${NAME}" "${VERSION}"
  else
    echo "Detected npm version: $(npm --version)"
  fi

  exit 0
fi

if [[ "${NAME}" == "pnpm" ]]; then
  if command -v pnpm > /dev/null 2>&1; then
    echo "Found pnpm installation, removing it"

    ${SUDO} rm -rf "$(pnpm store path)" > /dev/null 2>&1
    ${SUDO} rm -rf "${PNPM_HOME}" > /dev/null 2>&1
    ${SUDO} npm rm -g pnpm > /dev/null 2>&1
  fi

  if [[ -z "${VERSION}" ]]; then
    VERSION=$(npm view pnpm version)
  fi

  ${SUDO} npm i -g pnpm@"${VERSION}"
  check_instalation "${NAME}" "${VERSION}"

  echo "Setting ~/.pnpm-store as the store directory"

  pnpm config set store-dir ~/.pnpm-store

  exit 0
fi

echo "Failed to ensure package manager"
echo "Please specify supported package manager through parameter or environment"

exit 1
