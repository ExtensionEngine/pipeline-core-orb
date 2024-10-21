#!/bin/bash

if [ ! -f "package.json" ]; then
  echo "File package.json not found inside working directory: ${PWD}"
  echo "Content of working directory:"

  ls -al

  exit 1
fi
