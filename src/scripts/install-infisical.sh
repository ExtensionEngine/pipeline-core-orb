#!/bin/bash

INFISICAL_RELEASES_URL="https://github.com/Infisical/cli/releases"
INFISICAL_LATEST_RELEASE_URL="https://api.github.com/repos/Infisical/cli/releases/latest"
INFISICAL_DEST_DIR="/usr/local/bin"

resolve_target_version() {
  local target_version

  target_version="$1"

  if [[ -z "${target_version}" ]]; then
    echo "Infisical CLI target version not specified, falling back to the latest version" >&2

    target_version=$(curl -s "${INFISICAL_LATEST_RELEASE_URL}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  fi

  target_version="${target_version#v}"

  if [[ ! "${target_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid Infisical CLI version ${target_version} specified" >&2

    exit 1
  fi

  echo "${target_version}"
}

install_infisical() {
  local version
  local platform
  local architecture
  local download_url

  version="$1"

  case "$(uname -s)" in
  Linux) platform="linux" ;;
  Darwin) platform="darwin" ;;
  *)
    echo "Unsupported platform: $(uname -s). Supported platforms: Linux and Darwin." >&2
    return 1
    ;;
  esac

  case "$(uname -m)" in
  x86_64 | amd64) architecture="amd64" ;;
  arm64 | aarch64) architecture="arm64" ;;
  *)
    echo "Unsupported architecture: $(uname -m). Supported architectures: amd64 and arm64." >&2
    return 1
    ;;
  esac

  download_url="${INFISICAL_RELEASES_URL}/download/v${version}/cli_${version}_${platform}_${architecture}.tar.gz"

  set -x
  curl -sfL --retry 1 "${download_url}" | sudo tar xz -C "${INFISICAL_DEST_DIR}" infisical
  set +x

  echo "Installed Infisical CLI ${version} at ${INFISICAL_DEST_DIR}"
}

version=$(resolve_target_version "${PARAM_STR_VERSION}")

if command -v infisical >/dev/null 2>&1 && version_output=$(infisical --version 2>&1) && [[ "${version_output}" =~ v?([0-9]+\.[0-9]+\.[0-9]+) ]] && [[ "${BASH_REMATCH[1]}" == "${version}" ]]; then
  echo "Infisical CLI version ${version} is already installed"

  exit 0
fi

echo "Failed to detect Infisical CLI, installing..."

install_infisical "${version}"
