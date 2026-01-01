#!/bin/bash

set -exu

# where this .sh file lives
DIRNAME=$(dirname "$0")
SCRIPT_DIR=$(cd "$DIRNAME" || exit 1; pwd)
cd "$SCRIPT_DIR" || exit 1

git fetch \
  && git switch gh-pages \
  && git pull \
  && git rebase main -i \
  && git push --force \
  && git switch main
