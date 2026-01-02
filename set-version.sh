#!/bin/bash

# where this .sh file lives
DIRNAME=$(dirname "$0")
SCRIPT_DIR=$(cd "$DIRNAME" || exit 1; pwd)
cd "$SCRIPT_DIR" || exit 1

CHART_NAME=$1
CHART_DIR="./charts"
VERSIONS_SRC="./src/versions.yaml"

# Read versions from versions.yaml
DESCRIPTION=$(yq eval ".${CHART_NAME}.description" $VERSIONS_SRC)
CHART_VERSION=$(yq eval ".${CHART_NAME}.chart" $VERSIONS_SRC)
APP_VERSION=$(yq eval ".${CHART_NAME}.application" $VERSIONS_SRC)

# Update Chart.yaml with the new versions
yq eval --inplace ".description = \"$DESCRIPTION\"" "$CHART_DIR/${CHART_NAME}/Chart.yaml"
yq eval --inplace ".version = \"$CHART_VERSION\"" "$CHART_DIR/${CHART_NAME}/Chart.yaml"
yq eval --inplace ".appVersion = \"$APP_VERSION\"" "$CHART_DIR/${CHART_NAME}/Chart.yaml"

echo "Updated Chart.yaml for ${CHART_NAME} with chart version: $CHART_VERSION and app version: $APP_VERSION"
