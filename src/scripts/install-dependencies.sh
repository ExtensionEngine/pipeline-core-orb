#!/bin/bash

REPORTED_CACHE_PATH=""

configure_cache_path() {
  if [[ -z "${RESOLVED_DEPENDENCY_CACHE_PATH:-}" ]]; then
    echo "Dependency cache path was not resolved" >&2

    exit 1
  fi

  if [[ "${CURRENT_PKG_MANAGER}" == "npm" ]]; then
    export npm_config_cache="${RESOLVED_DEPENDENCY_CACHE_PATH}"
    REPORTED_CACHE_PATH=$(npm config get cache)
  elif [[ "${CURRENT_PKG_MANAGER}" == "pnpm" ]]; then
    export npm_config_store_dir="${RESOLVED_DEPENDENCY_CACHE_PATH}"
    export pnpm_config_store_dir="${RESOLVED_DEPENDENCY_CACHE_PATH}"
    REPORTED_CACHE_PATH=$(pnpm store path)
  else
    echo "Cannot install dependencies with unsupported package manager '${CURRENT_PKG_MANAGER}'" >&2

    exit 1
  fi

  if ! REPORTED_CACHE_PATH=$(cd "$(dirname "${REPORTED_CACHE_PATH}")" && printf '%s/%s' "$(pwd -P)" "$(basename "${REPORTED_CACHE_PATH}")"); then
    echo "${CURRENT_PKG_MANAGER} reported an unusable dependency cache path: ${REPORTED_CACHE_PATH}" >&2

    exit 1
  fi

  if [[ "${CURRENT_PKG_MANAGER}" == "npm" && "${REPORTED_CACHE_PATH}" != "${RESOLVED_DEPENDENCY_CACHE_PATH}" ]]; then
    echo "npm is not using the requested dependency cache path" >&2
    echo "Expected cache path: ${RESOLVED_DEPENDENCY_CACHE_PATH}" >&2
    echo "Reported cache path: ${REPORTED_CACHE_PATH}" >&2

    exit 1
  fi

  if [[ "${CURRENT_PKG_MANAGER}" == "pnpm" && "${REPORTED_CACHE_PATH}" != "${RESOLVED_DEPENDENCY_CACHE_PATH}"/v[0-9]* ]]; then
    echo "pnpm is not using the requested dependency cache path" >&2
    echo "Expected store root: ${RESOLVED_DEPENDENCY_CACHE_PATH}" >&2
    echo "Reported store path: ${REPORTED_CACHE_PATH}" >&2

    exit 1
  fi

  echo "Using ${CURRENT_PKG_MANAGER} dependency cache path: ${RESOLVED_DEPENDENCY_CACHE_PATH}"
}

configure_cache_path

if [[ -n "${PARAM_STR_INSTALL_COMMAND}" ]]; then
  echo "Running custom install command"

  exec bash -o pipefail -c "${PARAM_STR_INSTALL_COMMAND}"
elif [[ "${CURRENT_PKG_MANAGER}" == "npm" ]]; then
  echo "Running npm clean install"

  npm ci
else
  echo "Running pnpm install with frozen lockfile"

  pnpm i --frozen-lockfile
fi
