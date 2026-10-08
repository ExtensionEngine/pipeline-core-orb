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
  local reference

  assert_fails "Package manager 'yarn' is not supported" \
    env PARAM_STR_PKG_MANAGER=yarn BASH_ENV="${BASH_ENV_FILE}" \
    bash "${SCRIPTS_DIR}/export-pkg-manager.sh"

  for reference in npm@ 'npm@next tag' 'npm@10.0.0@rc.1' 'npm@^11' 'npm@file:./npm' 'npm@https://example.test/npm.tgz' 'npm@11.0.0-rc.1' 'npm@11.0.0+build.1'; do
    assert_fails "Package manager '${reference}' is not supported" \
      env PARAM_STR_PKG_MANAGER="${reference}" BASH_ENV="${BASH_ENV_FILE}" \
      bash "${SCRIPTS_DIR}/export-pkg-manager.sh"
  done

  for reference in pnpm@latest-10 npm@candidate_1.0; do
    : >"${BASH_ENV_FILE}"
    env PARAM_STR_PKG_MANAGER="${reference}" BASH_ENV="${BASH_ENV_FILE}" \
      bash "${SCRIPTS_DIR}/export-pkg-manager.sh" >/dev/null
  done

  assert_fails "Package manager 'missing-pkg-manager-for-negative-test' is not available" \
    env CURRENT_PKG_MANAGER=missing-pkg-manager-for-negative-test \
    bash "${SCRIPTS_DIR}/validate-pkg-manager.sh"
}

test_package_manager_dist_tag_resolution() {
  local fake_bin="${TEMP_DIR}/package-manager-bin"
  local version_file="${fake_bin}/version"
  local malformed_version

  mkdir -p "${fake_bin}" "${TEST_HOME}/npm-root"

  cat >"${fake_bin}/fake-package-manager" <<'EOF'
#!/bin/bash
set -euo pipefail

case "$*" in
"root -g")
  printf '%s\n' "${HOME}/npm-root"
  ;;
"dist-tag ls "*)
  printf '%b' "${TEST_DIST_TAG_OUTPUT}"
  ;;
"i -g "*)
  expected_ref="${CURRENT_PKG_MANAGER}@${CURRENT_PKG_MANAGER_VERSION}"
  if [[ "$3" != "${expected_ref}" ]]; then
    printf 'Expected install reference %s, got %s\n' "${expected_ref}" "$3" >&2
    exit 1
  fi
  package_name=${3%%@*}
  printf '%s\n' "${TEST_INSTALL_VERSION}" >"${TEST_VERSION_FILE}"
  ln -sf fake-package-manager "${TEST_FAKE_BIN}/${package_name}"
  ;;
--version)
  cat "${TEST_VERSION_FILE}"
  ;;
*)
  printf 'Unexpected invocation: %s %s\n' "${0##*/}" "$*" >&2
  exit 1
  ;;
esac
EOF

  chmod +x "${fake_bin}/fake-package-manager"
  ln -s fake-package-manager "${fake_bin}/npm"

  run_dist_tag_case() {
    local manager=$1 tag=$2 registry_output=$3 installed_version=${4:-}

    rm -f "${fake_bin}/pnpm"
    printf '10.0.0\n' >"${version_file}"

    env PATH="${fake_bin}:/usr/bin:/bin" \
      HOME="${TEST_HOME}" \
      CURRENT_PKG_MANAGER="${manager}" \
      CURRENT_PKG_MANAGER_VERSION="${tag}" \
      TEST_DIST_TAG_OUTPUT="${registry_output}" \
      TEST_FAKE_BIN="${fake_bin}" \
      TEST_INSTALL_VERSION="${installed_version}" \
      TEST_VERSION_FILE="${version_file}" \
      bash "${SCRIPTS_DIR}/ensure-pkg-manager.sh"
  }

  assert_status 0 "Installed npm version: 11.0.0-beta.2" run_dist_tag_case \
    npm next $'latest: 10.9.0\nnext: 11.0.0-beta.2\n' 11.0.0-beta.2
  assert_status 0 "Installed pnpm version: 11.0.0-rc.1+build.5" run_dist_tag_case \
    pnpm beta $'beta: 11.0.0-rc.1+build.5\nlatest: 10.5.1\n' 11.0.0-rc.1+build.5
  assert_status 0 "Installed npm version: 11.0.0" run_dist_tag_case \
    npm latest $'latest: 11.0.0\nnext: 12.0.0-beta.1\n' 11.0.0

  for malformed_version in 11.0 11.0.0- 11.0.0+; do
    assert_status 2 "Failed to resolve npm version/tag 'next'" run_dist_tag_case \
      npm next "next: ${malformed_version}\n"
  done

  assert_status 2 "Failed to resolve pnpm version/tag 'beta'" run_dist_tag_case \
    pnpm beta $'latest: 10.5.1\n'
  assert_status 2 "Failed to resolve npm version/tag 'next'" run_dist_tag_case \
    npm next $'next: 11.0.0-beta.1\nnext: 11.0.0-beta.2\n'
  assert_status 2 "Failed to install npm version: 11.0.0-beta.2" run_dist_tag_case \
    npm next $'next: 11.0.0-beta.2\n' 11.0.0-beta.3
}

test_pnpm_cleanup_guardrails() {
  local operations_file="${TEMP_DIR}/pnpm-cleanup.log"
  local safe_store="${TEMP_DIR}/pnpm-store"
  local unrelated_path="${TEMP_DIR}/unrelated-cache"

  mkdir -p "${TEST_HOME}/npm-root"

  run_pnpm_cleanup_case() {
    # This command is evaluated by the child Bash process.
    # shellcheck disable=SC2016
    env \
      HOME="${TEST_HOME}" \
      PNPM_HOME="$2" \
      PNPM_CLEANUP_STORE="$1" \
      PNPM_CLEANUP_LOG="${operations_file}" \
      CURRENT_PKG_MANAGER=pnpm \
      CURRENT_PKG_MANAGER_VERSION=10.5.1 \
      bash -c '
        npm() {
          if [[ "$*" == "root -g" ]]; then
            printf "%s\\n" "$HOME/npm-root"
          else
            printf "npm %s\\n" "$*" >>"$PNPM_CLEANUP_LOG"
          fi
        }

        pnpm() {
          case "$*" in
          --version) printf "9.0.0\\n" ;;
          "store path") printf "%s\\n" "$PNPM_CLEANUP_STORE" ;;
          esac
        }

        sudo() {
          "$@"
        }

        rm() {
          printf "rm %s\\n" "$*" >>"$PNPM_CLEANUP_LOG"
        }

        source "$1"
      ' _ "${SCRIPTS_DIR}/ensure-pkg-manager.sh"
  }

  assert_pnpm_cleanup_rejection() {
    local store_path=$1
    local pnpm_home=$2
    local expected_output=$3
    local expected_operations=$4
    local actual_operations

    : >"${operations_file}"
    assert_status 2 "${expected_output}" run_pnpm_cleanup_case "${store_path}" "${pnpm_home}"
    actual_operations=$(<"${operations_file}")

    if [[ "${actual_operations}" != "${expected_operations}" ]]; then
      fail "Unexpected pnpm cleanup operations; expected: ${expected_operations:-<none>}" "${actual_operations:-<none>}"
    fi
  }

  assert_pnpm_cleanup_rejection \
    / \
    "${TEMP_DIR}/pnpm-home" \
    "Refusing to remove unsafe pnpm store path: /" \
    ""

  assert_pnpm_cleanup_rejection \
    "${unrelated_path}" \
    "${TEMP_DIR}/pnpm-home" \
    "Refusing to remove pnpm store path without pnpm marker: ${unrelated_path}" \
    ""

  assert_pnpm_cleanup_rejection \
    "${safe_store}" \
    "${TEST_HOME}" \
    "Refusing to remove unsafe PNPM_HOME path: ${TEST_HOME}" \
    "rm -rf ${safe_store}"

  assert_pnpm_cleanup_rejection \
    "${safe_store}" \
    "${unrelated_path}" \
    "Refusing to remove PNPM_HOME path without pnpm marker: ${unrelated_path}" \
    "rm -rf ${safe_store}"
}

test_project_validation() {
  assert_fails "File package.json not found" \
    in_dir "${TEMP_DIR}" bash "${SCRIPTS_DIR}/check-pkg-json.sh"

  assert_fails "The lockfile not found!" \
    in_dir "${TEMP_DIR}/missing-lockfile" \
    env CURRENT_PKG_MANAGER=npm bash "${SCRIPTS_DIR}/process-lockfile.sh"
}

test_cache_metadata_failures() {
  run_cache_metadata_case() {
    local manager=$1 version=$2

    rm -f "${METADATA_FILE}"
    # This command is evaluated by the child Bash process.
    # shellcheck disable=SC2016
    env TEST_PKG_MANAGER_VERSION="${version}" bash -c '
      package_manager_version() { printf "%s\\n" "${TEST_PKG_MANAGER_VERSION}"; }
      npm() { package_manager_version; }
      pnpm() { package_manager_version; }
      CURRENT_PKG_MANAGER="$2" source "$1"
    ' _ "${SCRIPTS_DIR}/write-pkg-manager-cache-metadata.sh" "${manager}"
  }

  # This command is evaluated by the child Bash process.
  # shellcheck disable=SC2016
  assert_fails "Cannot write package manager cache metadata because pnpm version lookup failed" \
    bash -c 'pnpm() { return 1; }; CURRENT_PKG_MANAGER=pnpm source "$1"' _ \
    "${SCRIPTS_DIR}/write-pkg-manager-cache-metadata.sh"

  run_cache_metadata_case pnpm 10.5.1 >/dev/null
  [[ "$(<"${METADATA_FILE}")" == "package-manager=pnpm@10" ]] ||
    fail "Expected stable pnpm cache metadata to use its major version" "$(<"${METADATA_FILE}")"

  run_cache_metadata_case pnpm 10.5.1-rc.1+build.2 >/dev/null
  [[ "$(<"${METADATA_FILE}")" == "package-manager=pnpm@10" ]] ||
    fail "Expected prerelease pnpm cache metadata to use its major version" "$(<"${METADATA_FILE}")"

  run_cache_metadata_case npm 11.0.0-beta.2 >/dev/null
  [[ "$(<"${METADATA_FILE}")" == "package-manager=npm@11" ]] ||
    fail "Expected prerelease npm cache metadata to use its major version" "$(<"${METADATA_FILE}")"
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

test_run_script_non_disclosure() {
  local fake_bin="${TEMP_DIR}/run-script-bin"
  local arguments_file="${TEMP_DIR}/run-script-arguments"
  local script_argument="script-argument-secret-sentinel"
  local run_option="run-option-secret-sentinel"
  local output status actual_arguments expected_arguments

  mkdir -p "${fake_bin}"
  {
    printf '%s\n' '#!/bin/bash'
    # These expressions are evaluated by the generated fake npm executable.
    # shellcheck disable=SC2016
    printf '%s\n' 'printf '\''%s\n'\'' "$@" >"${RUN_SCRIPT_ARGUMENTS_FILE}"'
    # shellcheck disable=SC2016
    printf '%s\n' 'exit "${RUN_SCRIPT_EXIT_STATUS}"'
  } >"${fake_bin}/npm"
  chmod +x "${fake_bin}/npm"

  if output=$(env \
    PATH="${fake_bin}:${PATH}" \
    CURRENT_PKG_MANAGER=npm \
    PARAM_STR_SCRIPT=non-disclosure-test \
    PARAM_STR_SCRIPT_ARGS="${script_argument}" \
    PARAM_STR_RUN_OPTIONS="${run_option}" \
    RUN_SCRIPT_ARGUMENTS_FILE="${arguments_file}" \
    RUN_SCRIPT_EXIT_STATUS=44 \
    bash "${SCRIPTS_DIR}/run-script.sh" 2>&1); then
    status=0
  else
    status=$?
  fi

  [[ "${status}" -eq 44 ]] || fail "Expected run script status 44, got ${status}" "${output}"
  [[ "${output}" == *"Running package.json script 'non-disclosure-test'"* ]] ||
    fail "Expected run script diagnostic" "${output}"

  if [[ "${output}" == *"${script_argument}"* || "${output}" == *"${run_option}"* ]]; then
    fail "run_script must not log script arguments or run options" "${output}"
  fi

  actual_arguments=$(<"${arguments_file}")
  expected_arguments=$(printf '%s\n' run non-disclosure-test "${run_option}" -- "${script_argument}")
  [[ "${actual_arguments}" == "${expected_arguments}" ]] ||
    fail "run_script did not forward arguments in npm order" "${actual_arguments}"
}

test_infisical_archive_verification() {
  local fake_bin="${TEMP_DIR}/infisical-bin"
  local install_marker="${TEMP_DIR}/infisical-install.log"
  local version=0.43.119
  local linux_archive="cli_${version}_linux_amd64.tar.gz"
  local darwin_archive="cli_${version}_darwin_arm64.tar.gz"

  mkdir -p "${fake_bin}"

  cat >"${fake_bin}/fake-command" <<'EOF'
#!/bin/bash
set -euo pipefail
command_name=${0##*/}
case "${command_name}" in
uname)
  case "$1" in -s) printf '%s\n' "${INFISICAL_FAKE_PLATFORM}" ;; -m) printf '%s\n' "${INFISICAL_FAKE_ARCHITECTURE}" ;; *) exit 1 ;; esac
  ;;
curl)
  [[ $# -eq 7 && "$5" == -o ]] || exit 1
  output=$6 url=$7
  if [[ "${url}" == */cli_*.tar.gz ]]; then
    printf 'archive\n' >"${output}"
  elif [[ "${url##*/}" == "${INFISICAL_EXPECTED_MANIFEST}" ]]; then
    printf '%b\n' "${INFISICAL_MANIFEST}" >"${output}"
  else
    printf 'Unexpected Infisical URL: %s\n' "${url}" >&2
    exit 1
  fi
  ;;
sha256sum | shasum)
  [[ "${command_name} $*" == "${INFISICAL_EXPECTED_CHECKSUM_COMMAND}" ]] || exit 1
  read -r checksum archive <"${!#}"
  [[ "${checksum}" == valid && -n "${archive}" && -f "${archive}" ]]
  ;;
tar)
  printf '%s\n' tar >>"${INFISICAL_INSTALL_MARKER}"
  printf '#!/bin/bash\nprintf '\''v%s\\n'\''\n' "${INFISICAL_VERSION}" >"$4/infisical"
  chmod +x "$4/infisical"
  ;;
sudo)
  printf '%s\n' sudo >>"${INFISICAL_INSTALL_MARKER}"
  cp "$4" "${INFISICAL_FAKE_BIN}/infisical"
  chmod +x "${INFISICAL_FAKE_BIN}/infisical"
  ;;
*) exit 1 ;;
esac
EOF

  chmod +x "${fake_bin}/fake-command"
  local command_name

  for command_name in uname curl sha256sum shasum tar sudo; do
    ln -s fake-command "${fake_bin}/${command_name}"
  done

  run_infisical_case() {
    local platform=$1 architecture=$2 expected_manifest=$3 expected_checksum=$4 manifest=$5
    rm -f "${fake_bin}/infisical"
    : >"${install_marker}"
    env PATH="${fake_bin}:/usr/bin:/bin" \
      PARAM_STR_VERSION="${version}" \
      INFISICAL_VERSION="${version}" \
      INFISICAL_FAKE_PLATFORM="${platform}" \
      INFISICAL_FAKE_ARCHITECTURE="${architecture}" \
      INFISICAL_FAKE_BIN="${fake_bin}" \
      INFISICAL_EXPECTED_MANIFEST="${expected_manifest}" \
      INFISICAL_EXPECTED_CHECKSUM_COMMAND="${expected_checksum}" \
      INFISICAL_MANIFEST="${manifest}" \
      INFISICAL_INSTALL_MARKER="${install_marker}" \
      bash "${SCRIPTS_DIR}/install-infisical.sh"
  }

  assert_verification_rejected() {
    local manifest=$1 expected_output=$2
    assert_fails "${expected_output}" run_infisical_case \
      Linux x86_64 checksums.txt "sha256sum -c selected-checksum" "${manifest}"
    [[ ! -s "${install_marker}" ]] ||
      fail "Infisical verification failure must stop before extraction or installation" "$(<"${install_marker}")"
  }

  assert_status 0 "Installed and verified Infisical CLI ${version}" run_infisical_case \
    Linux x86_64 checksums.txt "sha256sum -c selected-checksum" "valid ${linux_archive}"
  assert_status 0 "Installed and verified Infisical CLI ${version}" run_infisical_case \
    Darwin arm64 checksums-darwin.txt "shasum -a 256 -c selected-checksum" "valid ${darwin_archive}"
  assert_verification_rejected \
    'valid other.tar.gz' "Unable to find a unique checksum for ${linux_archive}"
  assert_verification_rejected \
    "valid ${linux_archive}\nvalid ${linux_archive}" "Unable to find a unique checksum for ${linux_archive}"
  assert_verification_rejected \
    "invalid ${linux_archive}" "Infisical CLI checksum verification failed"
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
  test_package_manager_dist_tag_resolution
  test_pnpm_cleanup_guardrails
  test_project_validation
  test_cache_metadata_failures
  test_cache_path_safety
  test_run_script_non_disclosure
  test_infisical_archive_verification
  test_status_propagation
}

main "$@"
