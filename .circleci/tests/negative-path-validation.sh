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
  local output=${2:-}

  printf '%s\n' "${message}" >&2

  if [[ -n "${output}" ]]; then
    printf 'Actual output:\n%s\n' "${output}" >&2
  fi

  exit 1
}

assert_status() {
  local expected_status=$1
  local expected_output=$2
  local output status

  shift 2

  if output=$("$@" 2>&1); then
    status=0
  else
    status=$?
  fi

  if [[ "${status}" -ne "${expected_status}" ]]; then
    fail "Expected status ${expected_status}, got ${status}: $*" "${output}"
  fi

  if [[ "${output}" != *"${expected_output}"* ]]; then
    fail "Expected output to contain: ${expected_output}" "${output}"
  fi
}

assert_fails() {
  local expected_output=$1

  shift
  assert_status 1 "${expected_output}" "$@"
}

assert_metadata_absent() {
  local scenario=$1

  if [[ -e "${METADATA_FILE}" ]]; then
    fail "Unsafe ${scenario} must not produce dependency cache metadata"
  fi
}

in_dir() {
  local directory=$1

  shift
  (
    cd "${directory}"
    "$@"
  )
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

prepare_fixtures() {
  mkdir -p \
    "${TEST_HOME}" \
    "${TEMP_DIR}/missing-lockfile" \
    "${TEMP_DIR}/failing-script" \
    "${TEMP_DIR}/dependency-cache" \
    "${TEMP_DIR}/other-cache"

  ln -s "${TEST_HOME}" "${TEMP_DIR}/home-cache-link"
  printf '{"scripts":{"fail":"exit 42"}}\n' >"${TEMP_DIR}/failing-script/package.json"
}

test_node_validation() {
  # This command is evaluated by the child Bash process.
  # shellcheck disable=SC2016
  assert_fails "At least Node.js v22 is required!" \
    bash -c 'node() { printf "v21.99.99\\n"; }; source "$1"' _ \
    "${SCRIPTS_DIR}/check-node-version.sh"

  # This command is evaluated by the child Bash process.
  # shellcheck disable=SC2016
  assert_status 0 "Detected Node.js version: v22.0.0" \
    bash -c 'node() { printf "v22.0.0\\n"; }; source "$1"' _ \
    "${SCRIPTS_DIR}/check-node-version.sh"

  # This command is evaluated by the child Bash process.
  # shellcheck disable=SC2016
  assert_status 0 "Detected Node.js version: v24.0.0" \
    bash -c 'node() { printf "v24.0.0\\n"; }; source "$1"' _ \
    "${SCRIPTS_DIR}/check-node-version.sh"

  # This command is evaluated by the child Bash process.
  # shellcheck disable=SC2016
  assert_fails "Unable to parse Node.js version: version 20" \
    bash -c 'node() { printf "version 20\\n"; }; source "$1"' _ \
    "${SCRIPTS_DIR}/check-node-version.sh"
}

test_package_manager_validation() {
  assert_fails "Package manager 'yarn' is not supported" \
    env PARAM_STR_PKG_MANAGER=yarn BASH_ENV="${BASH_ENV_FILE}" \
    bash "${SCRIPTS_DIR}/export-pkg-manager.sh"

  assert_fails "Package manager 'missing-pkg-manager-for-negative-test' is not available" \
    env CURRENT_PKG_MANAGER=missing-pkg-manager-for-negative-test \
    bash "${SCRIPTS_DIR}/validate-pkg-manager.sh"
}

test_project_validation() {
  assert_fails "File package.json not found" \
    in_dir "${TEMP_DIR}" bash "${SCRIPTS_DIR}/check-pkg-json.sh"

  assert_fails "The lockfile not found!" \
    in_dir "${TEMP_DIR}/missing-lockfile" \
    env CURRENT_PKG_MANAGER=npm bash "${SCRIPTS_DIR}/process-lockfile.sh"
}

test_cache_metadata_failures() {
  # This command is evaluated by the child Bash process.
  # shellcheck disable=SC2016
  assert_fails "Cannot write package manager cache metadata because pnpm version lookup failed" \
    bash -c 'pnpm() { return 1; }; CURRENT_PKG_MANAGER=pnpm source "$1"' _ \
    "${SCRIPTS_DIR}/write-pkg-manager-cache-metadata.sh"

  # This command is evaluated by the child Bash process.
  # shellcheck disable=SC2016
  assert_fails "Cannot parse package manager version: version 10" \
    bash -c 'pnpm() { printf "version 10\\n"; }; CURRENT_PKG_MANAGER=pnpm source "$1"' _ \
    "${SCRIPTS_DIR}/write-pkg-manager-cache-metadata.sh"
}

test_cache_path_safety() {
  local path scenario

  for scenario in home-alias root-alias home-symlink; do
    rm -f "${METADATA_FILE}" "${LOCKFILE_FILE}"

    case "${scenario}" in
    home-alias)
      path="${TEST_HOME}/cache-path-alias/.."
      ;;
    root-alias)
      path=/tmp/../
      ;;
    home-symlink)
      path="${TEMP_DIR}/home-cache-link"
      ;;
    esac

    assert_fails "cache_path must not resolve to the filesystem root or the current user's home directory." \
      env HOME="${TEST_HOME}" \
      BASH_ENV="${BASH_ENV_FILE}" \
      PARAM_ENUM_CACHE_PATH_MODE=initialize \
      PARAM_STR_CACHE_PATH="${path}" \
      bash "${SCRIPTS_DIR}/resolve-dependency-cache-path.sh"
    assert_metadata_absent "${scenario}"
  done

  ln -s "${TEMP_DIR}/dependency-cache" "${TEMP_DIR}/cache-link"
  initialize_cache_path "${TEMP_DIR}/cache-link"
  rm "${TEMP_DIR}/cache-link"
  ln -s "${TEMP_DIR}/other-cache" "${TEMP_DIR}/cache-link"

  assert_fails "Dependency cache path changed after cache restoration" \
    env HOME="${TEST_HOME}" \
    RESOLVED_DEPENDENCY_CACHE_PATH="${RESOLVED_DEPENDENCY_CACHE_PATH}" \
    PARAM_ENUM_CACHE_PATH_MODE=verify \
    PARAM_STR_CACHE_PATH="${TEMP_DIR}/cache-link" \
    bash "${SCRIPTS_DIR}/resolve-dependency-cache-path.sh"
}

test_status_propagation() {
  assert_status 42 "Running package.json script 'fail'" \
    in_dir "${TEMP_DIR}/failing-script" \
    env CURRENT_PKG_MANAGER=npm \
    PARAM_STR_SCRIPT=fail \
    PARAM_STR_SCRIPT_ARGS= \
    PARAM_STR_RUN_OPTIONS= \
    bash "${SCRIPTS_DIR}/run-script.sh"

  assert_fails "Dependency cache path was not resolved" \
    env -u RESOLVED_DEPENDENCY_CACHE_PATH \
    CURRENT_PKG_MANAGER=npm \
    bash "${SCRIPTS_DIR}/install-dependencies.sh"

  assert_status 43 "Running custom install command" \
    env CURRENT_PKG_MANAGER=npm \
    RESOLVED_DEPENDENCY_CACHE_PATH="${TEMP_DIR}/dependency-cache" \
    PARAM_STR_INSTALL_COMMAND='exit 43' \
    bash "${SCRIPTS_DIR}/install-dependencies.sh"

  assert_fails "Running custom install command" \
    env CURRENT_PKG_MANAGER=npm \
    RESOLVED_DEPENDENCY_CACHE_PATH="${TEMP_DIR}/dependency-cache" \
    PARAM_STR_INSTALL_COMMAND='false | true' \
    bash "${SCRIPTS_DIR}/install-dependencies.sh"
}

main() {
  trap cleanup EXIT
  prepare_fixtures
  test_node_validation
  test_package_manager_validation
  test_project_validation
  test_cache_metadata_failures
  test_cache_path_safety
  test_status_propagation
}

main "$@"
