#!/bin/bash

NAME="${CURRENT_PKG_MANAGER}"
VERSION="${CURRENT_PKG_MANAGER_VERSION}"
SUDO=""
NPM_I_SUDO=""

if [[ ${EUID} -ne 0 ]]; then
  echo "Using sudo privileges, excluding npm install commands, to finish the process"

  SUDO="sudo"

  if [[ ! -w "$(npm root -g)" ]]; then
    echo "Missing write permission for global node_modules directory"
    echo "Using sudo privileges for npm install commands as well"

    NPM_I_SUDO="sudo"
  fi
fi

check_installation() {
  local pkg_manager
  local required_version
  local installed_version

  pkg_manager="$1"
  required_version="$2"
  installed_version=$("${pkg_manager}" --version)

  echo "Installed ${pkg_manager} version: ${installed_version}"
  echo "Required ${pkg_manager} version: ${required_version}"

  if [[ "${installed_version}" != "${required_version}" ]]; then
    echo "Failed to install ${pkg_manager} version: ${required_version}"

    exit 2
  fi
}

resolve_partial_version() {
  npm view "$1@$2" version --json | awk '
    match($0, /[0-9]+\.[0-9]+\.[0-9]+/) { version = substr($0, RSTART, RLENGTH) }
    END { if (version) print version; else exit 1 }
  '
}

resolve_required_version() {
  local pkg_manager
  local version_spec
  local resolved_version

  pkg_manager="$1"
  version_spec="$2"

  if [[ "${version_spec}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf '%s' "${version_spec}"
    return 0
  fi

  resolved_version=$(npm dist-tag ls "${pkg_manager}" | awk -v tag="${version_spec}" '$1 == tag ":" { print $2; found = 1 } END { exit found ? 0 : 1 }')

  if [[ -n "${resolved_version}" ]]; then
    echo "Resolved ${pkg_manager} dist-tag '${version_spec}' to ${resolved_version}" >&2
    printf '%s' "${resolved_version}"
    return 0
  fi

  if [[ "${version_spec}" =~ ^[0-9]+(\.[0-9]+)?$ ]] && resolved_version=$(resolve_partial_version "${pkg_manager}" "${version_spec}"); then
    echo "Resolved ${pkg_manager} version '${version_spec}' to ${resolved_version}" >&2
    printf '%s' "${resolved_version}"
    return 0
  fi

  echo "Failed to resolve ${pkg_manager} version/tag '${version_spec}'" >&2

  return 2
}

change_pnpm_store_dir_and_exit() {
  local current_store_dir
  local target_store_dir

  current_store_dir=$(pnpm store path)
  target_store_dir="${HOME}/.pnpm-store"

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
    if ! REQUIRED_VERSION=$(resolve_required_version "${NAME}" "${VERSION}"); then
      exit 2
    fi

    if [[ "$(npm --version)" == "${REQUIRED_VERSION}" ]]; then
      echo "Requested version of npm is already installed"
    else
      echo "Requested version of npm not found, updating detected version"

      ${NPM_I_SUDO} npm i -g npm@"${VERSION}"
      check_installation "${NAME}" "${REQUIRED_VERSION}"
    fi

    exit 0
  fi

  echo "Using detected version of npm"

  exit 0
fi

if [[ "${NAME}" == "pnpm" ]]; then
  if [[ -n "${VERSION}" ]]; then
    if ! REQUIRED_VERSION=$(resolve_required_version "${NAME}" "${VERSION}"); then
      exit 2
    fi
  fi

  if command -v pnpm >/dev/null 2>&1; then
    echo "Detected pnpm $(pnpm --version)"

    if [[ -z "${VERSION}" ]]; then
      echo "Using detected version of pnpm"

      change_pnpm_store_dir_and_exit
    fi

    if [[ "$(pnpm --version)" == "${REQUIRED_VERSION}" ]]; then
      echo "Requested version of pnpm is already installed"

      change_pnpm_store_dir_and_exit
    fi

    echo "Requested version of pnpm not found, removing detected version"

    ${SUDO} rm -rf "$(pnpm store path)" >/dev/null 2>&1
    ${SUDO} rm -rf "${PNPM_HOME}" >/dev/null 2>&1
    ${SUDO} npm rm -g pnpm >/dev/null 2>&1
  else
    echo "Did not detect pnpm, proceeding with installation"
  fi

  if [[ -z "${VERSION}" ]]; then
    VERSION=$(npm view pnpm version)
    REQUIRED_VERSION="${VERSION}"

    echo "Version not explicitly requested, opting for ${VERSION}"
  fi

  ${NPM_I_SUDO} npm i -g pnpm@"${VERSION}"
  check_installation "${NAME}" "${REQUIRED_VERSION}"

  echo "Setting ~/.pnpm-store as the store directory"

  pnpm config set store-dir ~/.pnpm-store

  exit 0
fi

echo "Failed to ensure package manager"
echo "Please specify supported package manager through parameter or environment"

exit 1
