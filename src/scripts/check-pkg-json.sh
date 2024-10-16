#!/bin/bash

if [ ! -f "package.json" ]; then
  echo "File package.json not found inside current directory: ${PWD}"
  echo "Content of current directory:"
  ls -al
  exit 1
fi
