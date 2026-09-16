#!/bin/bash

DEST_FILE="/tmp/node-cache-path"
CACHE_PATH="${PARAM_STR_CACHE_PATH:-}"
EFFECTIVE_CACHE_PATH=""

if [[ -z "${CACHE_PATH}" ]]; then
  echo "Dependency cache path was not provided" >&2
  echo "Set cache_path to an absolute path or a current-user home path beginning with ~/." >&2

  exit 1
fi

case "${CACHE_PATH}" in
  \~)
    EFFECTIVE_CACHE_PATH="${HOME}"
    ;;
  \~/*)
    EFFECTIVE_CACHE_PATH="${HOME}/${CACHE_PATH#\~/}"
    ;;
  /*)
    EFFECTIVE_CACHE_PATH="${CACHE_PATH}"
    ;;
  *)
    echo "Unsupported dependency cache path: ${CACHE_PATH}" >&2
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
printf '%s\n' "${CANONICAL_CACHE_PATH}" >|"${DEST_FILE}"
