#!/bin/bash

CACHE_MODE="${PARAM_STR_CACHE_MODE}"
CACHE_ROOT="${HOME}/.cache/pipeline-core-orb/dependency-cache"
CACHE_PATH=""
STAGED_CACHE_DIR=""

validate_cache_mode() {
  if [[ -z "${CACHE_MODE}" ]]; then
    echo "Dependency cache mode was not provided"
    echo "Set PARAM_STR_CACHE_MODE to one of: restore, prepare, cleanup"

    exit 1
  fi

  if [[ "${CACHE_MODE}" != "restore" && "${CACHE_MODE}" != "prepare" && "${CACHE_MODE}" != "cleanup" ]]; then
    echo "Unsupported dependency cache mode '${CACHE_MODE}'"
    echo "Set PARAM_STR_CACHE_MODE to one of: restore, prepare, cleanup"

    exit 1
  fi
}

resolve_cache_path() {
  if [[ -z "${CURRENT_PKG_MANAGER:-}" ]]; then
    echo "Package manager was not resolved"
    echo "Cannot ${CACHE_MODE} dependency cache without CURRENT_PKG_MANAGER"

    exit 1
  fi

  if [[ "${CURRENT_PKG_MANAGER}" == "npm" ]]; then
    CACHE_PATH=$(npm config get cache)
  elif [[ "${CURRENT_PKG_MANAGER}" == "pnpm" ]]; then
    CACHE_PATH=$(pnpm store path)
  else
    echo "Cannot ${CACHE_MODE} dependency cache for unsupported package manager '${CURRENT_PKG_MANAGER}'"

    exit 1
  fi

  STAGED_CACHE_DIR="${CACHE_ROOT}/${CURRENT_PKG_MANAGER}"
}

is_empty_dir() {
  [[ ! -d "$1" || -z "$(ls -A "$1")" ]]
}

restore_cache() {
  echo "Restoring dependency cache for ${CURRENT_PKG_MANAGER}"
  echo "Dependency cache staging root: ${CACHE_ROOT}"
  echo "Dependency cache staging path: ${STAGED_CACHE_DIR}"
  echo "Dependency cache target: ${CACHE_PATH}"

  mkdir -p "${CACHE_PATH}"

  if [[ ! -d "${STAGED_CACHE_DIR}" ]]; then
    echo "No staged ${CURRENT_PKG_MANAGER} cache found; continuing without restored dependency cache"

    exit 0
  fi

  if is_empty_dir "${STAGED_CACHE_DIR}"; then
    echo "Staged ${CURRENT_PKG_MANAGER} cache is empty; continuing without restored dependency cache"

    exit 0
  fi

  echo "Copying staged ${CURRENT_PKG_MANAGER} cache into package manager cache path"
  cp -a "${STAGED_CACHE_DIR}/." "${CACHE_PATH}/"
}

prepare_cache() {
  echo "Preparing dependency cache for ${CURRENT_PKG_MANAGER}"
  echo "Dependency cache source: ${CACHE_PATH}"
  echo "Dependency cache staging root: ${CACHE_ROOT}"
  echo "Dependency cache staging path: ${STAGED_CACHE_DIR}"

  rm -rf "${CACHE_ROOT}"
  mkdir -p "${STAGED_CACHE_DIR}"

  if [[ ! -d "${CACHE_PATH}" ]]; then
    echo "Dependency cache source does not exist; saving empty staged cache"

    exit 0
  fi

  if is_empty_dir "${CACHE_PATH}"; then
    echo "Dependency cache source is empty; saving empty staged cache"

    exit 0
  fi

  echo "Copying ${CURRENT_PKG_MANAGER} cache into staging path"
  cp -a "${CACHE_PATH}/." "${STAGED_CACHE_DIR}/"
}

cleanup_cache() {
  echo "Removing dependency cache staging root: ${CACHE_ROOT}"
  rm -rf "${CACHE_ROOT}"
}

validate_cache_mode

if [[ "${CACHE_MODE}" == "cleanup" ]]; then
  cleanup_cache

  exit 0
fi

resolve_cache_path

if [[ "${CACHE_MODE}" == "restore" ]]; then
  restore_cache
elif [[ "${CACHE_MODE}" == "prepare" ]]; then
  prepare_cache
fi
