#!/bin/bash

echo "Running custom script from package.json at ${PWD}"

set -x
eval "${CURRENT_PKG_MANAGER}" run "${PARAM_STR_SCRIPT}"
set +x
