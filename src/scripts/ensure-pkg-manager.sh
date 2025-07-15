#!/bin/bash

NAME="${CURRENT_PKG_MANAGER}"
VERSION="${CURRENT_PKG_MANAGER_VERSION}"
SUDO=""
NPM_SUDO=""

if [[ ${EUID} -ne 0 ]]; then
  echo "Using sudo privileges, excluding npm commands, to finish the process"

  SUDO="sudo"

  if [[ ! -w "$(npm root -g)" ]]; then
    echo "Missing write permission for global node_modules directory"
    echo "Using sudo privileges for npm commands as well"

    NPM_SUDO="sudo"
  fi
fi

check_installation() {
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

change_pnpm_store_dir_and_exit() {
  local current_store_dir
  local target_store_dir

  current_store_dir=$(pnpm store path)
  target_store_dir="${HOME}/.pnpm_store"

  if [[ "${current_store_dir}" != "${target_store_dir}" ]]; then
    echo "Changing the pnpm store directory"

    set -x
    pnpm config set store-dir "${target_store_dir}"
    ${SUDO} rm -rf "${current_store_dir}"
    set +x
  fi

  exit 0
}

echo "Starting to ensure '${NAME}' is set for usage"

cd ~ || echo "Cannot navigate to home, possible version mismatch"

if [[ "${NAME}" == "npm" ]]; then
  echo "Detected npm $(npm --version)"

  if [[ -n "${VERSION}" ]]; then
    if npm --version | grep "${VERSION}" >/dev/null 2>&1; then
      echo "Requested version of npm is already installed"
    else
      echo "Requested version of npm not found, updating detected version"

      ${NPM_SUDO} npm i -g npm@"${VERSION}"
      check_installation "${NAME}" "${VERSION}"
    fi

    exit 0
  fi

  echo "Using detected version of npm"

  exit 0
fi

if [[ "${NAME}" == "pnpm" ]]; then
  if command -v pnpm >/dev/null 2>&1; then
    echo "Detected pnpm $(pnpm --version)"

    if [[ -z "${VERSION}" ]]; then
      echo "Using detected version of pnpm"

      change_pnpm_store_dir_and_exit
    elif pnpm --version | grep "${VERSION}" >/dev/null 2>&1; then
      echo "Requested vesion of pnpm is already installed"

      change_pnpm_store_dir_and_exit
    fi

    echo "Requested version of pnpm not found, removing detected version"

    ${SUDO} rm -rf "$(pnpm store path)" >/dev/null 2>&1
    ${SUDO} rm -rf "${PNPM_HOME}" >/dev/null 2>&1
    ${NPM_SUDO} npm rm -g pnpm >/dev/null 2>&1
  else
    echo "Did not detect pnpm, proceeding with installation"
  fi

  if [[ -z "${VERSION}" ]]; then
    VERSION=$(npm view pnpm version)

    echo "Version not explicitly requested, opting for ${VERSION}"
  fi

  ${NPM_SUDO} npm i -g pnpm@"${VERSION}"
  check_installation "${NAME}" "${VERSION}"

  echo "Setting ~/.pnpm-store as the store directory"

  pnpm config set store-dir ~/.pnpm-store

  exit 0
fi

echo "Failed to ensure package manager"
echo "Please specify supported package manager through parameter or environment"

exit 1
