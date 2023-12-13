#!/bin/bash

if [ ! -f "package.json" ]; then
  echo
  echo "File package.json not found inside current directory: $(pwd)"
  echo
  echo "Content of current directory:"
  echo 
  ls
  exit 1
fi
