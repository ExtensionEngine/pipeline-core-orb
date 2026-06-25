#!/bin/bash

if [[ -z "${CURRENT_PKG_MANAGER}" ]]; then
  echo "Package manager was not resolved"
  echo "Please resolve it with the pkg_manager parameter or DEFAULT_PKG_MANAGER environment variable"

  exit 1
fi

if ! command -v "${CURRENT_PKG_MANAGER}" >/dev/null 2>&1; then
  echo "Package manager '${CURRENT_PKG_MANAGER}' is not available"
  echo "Run ensure_pkg_manager before this command or use an execution environment that already includes ${CURRENT_PKG_MANAGER}"

  exit 1
fi

echo "Using ${CURRENT_PKG_MANAGER} $(${CURRENT_PKG_MANAGER} --version)"
