#!/bin/bash

REPORTED_CACHE_PATH=""

configure_cache_path() {
  local expected_cache_path

  if ! expected_cache_path=$(<"/tmp/node-cache-path"); then
    echo "Cannot read the resolved dependency cache path" >&2

    exit 1
  fi

  if [[ -z "${expected_cache_path}" ]]; then
    echo "Resolved dependency cache path is empty" >&2

    exit 1
  fi

  if ! expected_cache_path=$(cd "${expected_cache_path}" && pwd -P); then
    echo "Resolved dependency cache path is unusable: ${expected_cache_path}" >&2

    exit 1
  fi

  if [[ "${CURRENT_PKG_MANAGER}" == "npm" ]]; then
    export npm_config_cache="${expected_cache_path}"
    REPORTED_CACHE_PATH=$(npm config get cache)
  elif [[ "${CURRENT_PKG_MANAGER}" == "pnpm" ]]; then
    export npm_config_store_dir="${expected_cache_path}"
    export pnpm_config_store_dir="${expected_cache_path}"
    REPORTED_CACHE_PATH=$(pnpm store path)
  else
    echo "Cannot install dependencies with unsupported package manager '${CURRENT_PKG_MANAGER}'" >&2

    exit 1
  fi

  if ! REPORTED_CACHE_PATH=$(cd "$(dirname "${REPORTED_CACHE_PATH}")" && printf '%s/%s' "$(pwd -P)" "$(basename "${REPORTED_CACHE_PATH}")"); then
    echo "${CURRENT_PKG_MANAGER} reported an unusable dependency cache path: ${REPORTED_CACHE_PATH}" >&2

    exit 1
  fi

  if [[ "${CURRENT_PKG_MANAGER}" == "npm" && "${REPORTED_CACHE_PATH}" != "${expected_cache_path}" ]]; then
    echo "npm is not using the requested dependency cache path" >&2
    echo "Expected cache path: ${expected_cache_path}" >&2
    echo "Reported cache path: ${REPORTED_CACHE_PATH}" >&2

    exit 1
  fi

  if [[ "${CURRENT_PKG_MANAGER}" == "pnpm" && "${REPORTED_CACHE_PATH}" != "${expected_cache_path}"/v[0-9]* ]]; then
    echo "pnpm is not using the requested dependency cache path" >&2
    echo "Expected store root: ${expected_cache_path}" >&2
    echo "Reported store path: ${REPORTED_CACHE_PATH}" >&2

    exit 1
  fi

  echo "Using ${CURRENT_PKG_MANAGER} dependency cache path: ${expected_cache_path}"
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
