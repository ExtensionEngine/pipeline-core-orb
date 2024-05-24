# Core Orb [![CircleCI Build Status](https://circleci.com/gh/ExtensionEngine/pipeline-core-orb.svg?style=shield "CircleCI Build Status")](https://circleci.com/gh/ExtensionEngine/pipeline-core-orb) [![CircleCI Orb Version](https://badges.circleci.com/orbs/studion/core.svg)](https://circleci.com/developer/orbs/orb/studion/core) [![GitHub License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/ExtensionEngine/pipeline-core-orb/master/LICENSE) [![CircleCI Community](https://img.shields.io/badge/community-CircleCI%20Discuss-343434.svg)](https://discuss.circleci.com/c/ecosystem/orbs)

An orb to facilitate Node.js work within Studion CircleCI pipelines. Inspired by CircleCI Node Orb.\
Key features:
- Support for pnpm using Corepack, and npm
- Ensure the specific version/tag of the package manager is installed
- The default value of the package manager is picked from the environment
- Install dependencies with caching enabled by default
- Run scripts defined inside a package.json using a command for better composition
- Can only run in execution environments with Node.js pre-installed

## Usage

See [the official registry page](https://circleci.com/developer/orbs/orb/studion/core) of this orb for guidelines and examples.
