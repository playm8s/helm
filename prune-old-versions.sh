#!/bin/bash

set -exu

# where this .sh file lives
DIRNAME=$(dirname "$0")
SCRIPT_DIR=$(cd "$DIRNAME" || exit 1; pwd)
cd "$SCRIPT_DIR" || exit 1

git fetch \
  && git switch gh-pages \
  && git pull

yq eval '.entries.pm8s-operator = [.entries.pm8s-operator[0]]' index.yaml -i

git rebase main -i \
  && git push --force
