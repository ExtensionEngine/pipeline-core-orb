#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="${PWD}/src/scripts"
TEMP_DIR=$(cd "$(mktemp -d)" && pwd -P)
TEST_HOME="${TEMP_DIR}/home"
BASH_ENV_FILE="${TEMP_DIR}/bash_env"
METADATA_FILE="/tmp/node-cache-metadata"
LOCKFILE_FILE="/tmp/node-lockfile"

cleanup() {
  rm -rf "${TEMP_DIR}" "${METADATA_FILE}" "${LOCKFILE_FILE}"
}

fail() {
  local message=$1

  printf '%s\n' "${message}" >&2
  exit 1
}

assert_equals() {
  local expected=$1
  local actual=$2
  local message=$3

  if [[ "${actual}" != "${expected}" ]]; then
    fail "${message}\nExpected: ${expected}\nActual: ${actual}"
  fi
}

initialize_cache_path() {
  local cache_path=$1

  : >"${BASH_ENV_FILE}"
  env HOME="${TEST_HOME}" \
    BASH_ENV="${BASH_ENV_FILE}" \
    PARAM_ENUM_CACHE_PATH_MODE=initialize \
    PARAM_STR_CACHE_PATH="${cache_path}" \
    bash "${SCRIPTS_DIR}/resolve-dependency-cache-path.sh"
  # shellcheck source=/dev/null
  source "${BASH_ENV_FILE}"
}

verify_cache_path() {
  local cache_path=$1

  env HOME="${TEST_HOME}" \
    RESOLVED_DEPENDENCY_CACHE_PATH="${RESOLVED_DEPENDENCY_CACHE_PATH}" \
    PARAM_ENUM_CACHE_PATH_MODE=verify \
    PARAM_STR_CACHE_PATH="${cache_path}" \
    bash "${SCRIPTS_DIR}/resolve-dependency-cache-path.sh"
}

prepare_fixtures() {
  mkdir -p "${TEST_HOME}" "${TEMP_DIR}/cache-project"
  printf '{"lockfileVersion":3}\n' >"${TEMP_DIR}/cache-project/package-lock.json"
}

test_absolute_path_metadata_contract() {
  local expected_metadata metadata_sum node_major npm_major safe_cache_path

  bash "${SCRIPTS_DIR}/write-node-version-cache-metadata.sh"
  CURRENT_PKG_MANAGER=npm bash "${SCRIPTS_DIR}/write-pkg-manager-cache-metadata.sh"

  initialize_cache_path "${TEMP_DIR}/safe-cache"
  safe_cache_path=$(cd "${TEMP_DIR}/safe-cache" && pwd -P)
  assert_equals "${safe_cache_path}" "${RESOLVED_DEPENDENCY_CACHE_PATH}" \
    "Expected absolute dependency cache path export to be canonical"

  node_major=$(node -p 'process.versions.node.split(".")[0]')
  npm_major=$(npm --version | cut -d. -f1)
  expected_metadata=$(printf 'node-major=%s\npackage-manager=npm@%s\ncache-path=%s' \
    "${node_major}" "${npm_major}" "${safe_cache_path}")
  assert_equals "${expected_metadata}" "$(cat "${METADATA_FILE}")" \
    "Expected deterministic Node.js, package manager, and cache path metadata"

  in_cache_project() {
    cd "${TEMP_DIR}/cache-project"
    CURRENT_PKG_MANAGER=npm bash "${SCRIPTS_DIR}/process-lockfile.sh"
  }
  in_cache_project
  assert_equals "$(cat "${TEMP_DIR}/cache-project/package-lock.json")" "$(cat "${LOCKFILE_FILE}")" \
    "Expected lockfile cache input to remain separate"

  metadata_sum=$(shasum -a 256 "${METADATA_FILE}")
  metadata_sum=${metadata_sum%% *}
  verify_cache_path "${TEMP_DIR}/safe-cache"
  assert_equals "${metadata_sum}" "$(shasum -a 256 "${METADATA_FILE}" | cut -d' ' -f1)" \
    "Cache metadata changed during path verification"
}

test_home_path_canonicalization() {
  local safe_cache_path

  # The resolver expands this literal current-user home path.
  # shellcheck disable=SC2088
  initialize_cache_path '~/.cache/pipeline-core-orb-negative-path-cache'
  safe_cache_path=$(cd "${TEST_HOME}/.cache/pipeline-core-orb-negative-path-cache" && pwd -P)
  assert_equals "${safe_cache_path}" "${RESOLVED_DEPENDENCY_CACHE_PATH}" \
    "Expected home dependency cache path export to be canonical"
}

main() {
  trap cleanup EXIT
  prepare_fixtures
  test_absolute_path_metadata_contract
  test_home_path_canonicalization
}

main "$@"
