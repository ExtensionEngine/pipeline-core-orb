#!/bin/bash

set -euo pipefail

INFISICAL_RELEASES_URL="https://github.com/Infisical/cli/releases"
INFISICAL_LATEST_RELEASE_URL="https://api.github.com/repos/Infisical/cli/releases/latest"
INFISICAL_DEST_DIR="/usr/local/bin"

fail() {
  printf '%s\n' "$1" >&2

  exit 1
}

reported_version() {
  local executable=$1
  local output

  output=$("${executable}" --version 2>&1) || return 1

  if [[ "${output}" =~ (^|[^0-9.])v?([0-9]+\.[0-9]+\.[0-9]+)([^0-9.]|$) ]]; then
    printf '%s\n' "${BASH_REMATCH[2]}"

    return 0
  fi

  return 1
}

resolve_target_version() {
  local version=$1
  local error_message="Invalid Infisical CLI version specified: ${version}"

  if [[ -z "${version}" ]]; then
    printf '%s\n' "Infisical CLI target version not specified, resolving latest release" >&2
    version=$(curl -fsSL --retry 2 --retry-all-errors "${INFISICAL_LATEST_RELEASE_URL}" |
      sed -nE 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p') ||
      fail "Unable to retrieve the latest Infisical CLI release metadata"
    error_message="Unable to resolve a valid latest Infisical CLI version"
  fi

  version=${version#v}
  [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "${error_message}"
  printf '%s\n' "${version}"
}

detect_release_target() {
  local platform
  local architecture

  case "$(uname -s)" in
  Linux) platform="linux" ;;
  Darwin) platform="darwin" ;;
  *) fail "Unsupported platform: $(uname -s). Supported platforms: Linux and Darwin." ;;
  esac

  case "$(uname -m)" in
  x86_64 | amd64) architecture="amd64" ;;
  arm64 | aarch64) architecture="arm64" ;;
  *) fail "Unsupported architecture: $(uname -m). Supported architectures: amd64 and arm64." ;;
  esac

  printf '%s_%s\n' "${platform}" "${architecture}"
}

download_verified_archive() {
  local version=$1
  local archive_name=$2
  local release_target=$3
  local temp_dir=$4
  local checksum_file=checksums.txt

  if [[ "${release_target}" == darwin_* ]]; then
    checksum_file=checksums-darwin.txt
  fi

  curl -fsSL --retry 2 --retry-all-errors \
    -o "${temp_dir}/${archive_name}" \
    "${INFISICAL_RELEASES_URL}/download/v${version}/${archive_name}" ||
    fail "Unable to download Infisical CLI release asset: ${archive_name}"
  curl -fsSL --retry 2 --retry-all-errors \
    -o "${temp_dir}/${checksum_file}" \
    "${INFISICAL_RELEASES_URL}/download/v${version}/${checksum_file}" ||
    fail "Unable to download Infisical CLI checksums"

  awk -v archive="${archive_name}" '$2 == archive' "${temp_dir}/${checksum_file}" >"${temp_dir}/selected-checksum"

  [[ $(wc -l <"${temp_dir}/selected-checksum") -eq 1 ]] || fail "Unable to find a unique checksum for ${archive_name}"

  if [[ "${release_target}" == darwin_* ]]; then
    (cd "${temp_dir}" && shasum -a 256 -c selected-checksum)
  else
    (cd "${temp_dir}" && sha256sum -c selected-checksum)
  fi || fail "Infisical CLI checksum verification failed"
}

validate_selected_command() {
  local expected_version=$1
  local executable
  local observed_version

  hash -r
  executable=$(command -v infisical) || fail "Infisical CLI is unavailable on PATH after installation"
  observed_version=$(reported_version "${executable}") || fail "Unable to determine Infisical CLI version from ${executable}"

  [[ "${observed_version}" == "${expected_version}" ]] ||
    fail "Infisical CLI selected from PATH has version ${observed_version}; expected ${expected_version}"
}

install_infisical() (
  local version=$1
  local archive_name
  local release_target
  local temp_dir

  release_target=$(detect_release_target)
  archive_name="cli_${version}_${release_target}.tar.gz"
  temp_dir=$(mktemp -d) || fail "Unable to create a temporary directory for Infisical CLI installation"
  trap 'rm -rf -- "${temp_dir}"' EXIT

  download_verified_archive "${version}" "${archive_name}" "${release_target}" "${temp_dir}"

  tar -xzf "${temp_dir}/${archive_name}" -C "${temp_dir}" infisical ||
    fail "Unable to extract Infisical CLI executable from ${archive_name}"

  sudo install -m 0755 "${temp_dir}/infisical" "${INFISICAL_DEST_DIR}/infisical" ||
    fail "Unable to install Infisical CLI at ${INFISICAL_DEST_DIR}/infisical"

  validate_selected_command "${version}"
  printf 'Installed and verified Infisical CLI %s at %s/infisical\n' "${version}" "${INFISICAL_DEST_DIR}"
)

version=$(resolve_target_version "${PARAM_STR_VERSION}")

if command -v infisical >/dev/null 2>&1 &&
  installed_version=$(reported_version "$(command -v infisical)") &&
  [[ "${installed_version}" == "${version}" ]]; then
  printf 'Infisical CLI version %s is already installed\n' "${version}"

  exit 0
fi

printf '%s\n' "Failed to detect Infisical CLI, installing..."

install_infisical "${version}"
