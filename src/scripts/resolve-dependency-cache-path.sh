#!/bin/bash

CACHE_METADATA_FILE="/tmp/node-cache-metadata"
EFFECTIVE_CACHE_PATH=""
CANONICAL_CACHE_PATH=""
CANONICAL_HOME=""

if [[ "${PARAM_ENUM_CACHE_PATH_MODE}" != "initialize" && "${PARAM_ENUM_CACHE_PATH_MODE}" != "verify" ]]; then
  echo "Unsupported dependency cache path mode: ${PARAM_ENUM_CACHE_PATH_MODE:-<empty>}" >&2
  echo "Set PARAM_ENUM_CACHE_PATH_MODE to initialize or verify." >&2

  exit 1
fi

if [[ -z "${PARAM_STR_CACHE_PATH}" ]]; then
  echo "Dependency cache path was not provided" >&2
  echo "Set cache_path to an absolute path or a current-user home path beginning with ~/." >&2

  exit 1
fi

case "${PARAM_STR_CACHE_PATH}" in
\~)
  EFFECTIVE_CACHE_PATH="${HOME}"
  ;;
\~/*)
  EFFECTIVE_CACHE_PATH="${HOME}/${PARAM_STR_CACHE_PATH#\~/}"
  ;;
/*)
  EFFECTIVE_CACHE_PATH="${PARAM_STR_CACHE_PATH}"
  ;;
*)
  echo "Unsupported dependency cache path: ${PARAM_STR_CACHE_PATH}" >&2
  echo "Set cache_path to an absolute path or a current-user home path beginning with ~/." >&2

  exit 1
  ;;
esac

while [[ "${EFFECTIVE_CACHE_PATH}" != "/" && "${EFFECTIVE_CACHE_PATH}" == */ ]]; do
  EFFECTIVE_CACHE_PATH="${EFFECTIVE_CACHE_PATH%/}"
done

if ! CANONICAL_HOME=$(cd "${HOME}" && pwd -P); then
  echo "Cannot resolve current user's home directory: ${HOME}" >&2

  exit 1
fi

if ! mkdir -p "${EFFECTIVE_CACHE_PATH}"; then
  echo "Cannot create dependency cache path: ${EFFECTIVE_CACHE_PATH}" >&2

  exit 1
fi

if ! CANONICAL_CACHE_PATH=$(cd "${EFFECTIVE_CACHE_PATH}" && pwd -P); then
  echo "Cannot resolve dependency cache path: ${EFFECTIVE_CACHE_PATH}" >&2

  exit 1
fi

if [[ "${CANONICAL_CACHE_PATH}" == "/" || "${CANONICAL_CACHE_PATH}" == "${CANONICAL_HOME}" ]]; then
  echo "Refusing to use unsafe dependency cache path: ${CANONICAL_CACHE_PATH}" >&2
  echo "cache_path must not resolve to the filesystem root or the current user's home directory." >&2

  exit 1
fi

if [[ ! -w "${EFFECTIVE_CACHE_PATH}" ]]; then
  echo "Dependency cache path is not writable: ${EFFECTIVE_CACHE_PATH}" >&2

  exit 1
fi

echo "Using dependency cache path: ${CANONICAL_CACHE_PATH}"

if [[ "${PARAM_ENUM_CACHE_PATH_MODE}" == "initialize" ]]; then
  if [[ -z "${BASH_ENV:-}" ]]; then
    echo "Cannot export resolved dependency cache path because BASH_ENV is not set" >&2

    exit 1
  fi

  if ! printf 'export RESOLVED_DEPENDENCY_CACHE_PATH=%q\n' "${CANONICAL_CACHE_PATH}" >>"${BASH_ENV}"; then
    echo "Cannot export resolved dependency cache path to BASH_ENV" >&2

    exit 1
  fi

  if ! printf 'cache-path=%s\n' "${CANONICAL_CACHE_PATH}" >>"${CACHE_METADATA_FILE}"; then
    echo "Cannot append dependency cache path metadata" >&2

    exit 1
  fi
elif [[ -z "${RESOLVED_DEPENDENCY_CACHE_PATH:-}" ]]; then
  echo "Dependency cache path was not initialized" >&2

  exit 1
elif [[ "${CANONICAL_CACHE_PATH}" != "${RESOLVED_DEPENDENCY_CACHE_PATH}" ]]; then
  echo "Dependency cache path changed after cache restoration" >&2
  echo "Initialized cache path: ${RESOLVED_DEPENDENCY_CACHE_PATH}" >&2
  echo "Current cache path: ${CANONICAL_CACHE_PATH}" >&2

  exit 1
fi
