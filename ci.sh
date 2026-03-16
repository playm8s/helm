#!/bin/bash

GENERATED_CHARTS=(crds operator)
HANDWRITTEN_CHARTS=(gameserver-csgo)
META_CHARTS=()

COMMIT="$(git rev-parse --short --verify main)"

# Check if we're running in GitHub CI/CD environment
IS_GITHUB_CI=false
if [[ -n "$GITHUB_ACTIONS" ]]; then
  IS_GITHUB_CI=true
fi

# where this .sh file lives
DIRNAME=$(dirname "$0")
SCRIPT_DIR=$(cd "${DIRNAME}" || exit 1; pwd)
cd "${SCRIPT_DIR}" || exit 1

VERSIONS_SRC="${VERSIONS_SRC:-"${SCRIPT_DIR}/versions.yaml"}"
CHART_DIR="${CHART_DIR:-"${SCRIPT_DIR}/charts"}"
CHART_SRC_DIR="${CHART_SRC_DIR:-"${SCRIPT_DIR}/src"}"

function main() {
  cd "$SCRIPT_DIR" || exit 1

  if [[ "$IS_GITHUB_CI" == true ]]; then
    setup_git_ci
    update_readme_gh_pages_branch
    setup_npm_ci
  else
    echo "Running in local environment - skipping CI setup functions"
  fi

  echo "Cleanup"
  rm -rf dist/*

  # generated charts
  echo "Run typescript build"
  if [[ "$IS_GITHUB_CI" == true ]]; then
    npm ci
  else
    echo "Skipping npm ci in local environment"
  fi
  npx tsc

  for CHART in "${GENERATED_CHARTS[@]}"; do
    echo "Processing chart: $CHART"

    cd dist || exit 1
    node "${CHART}.mjs"

    PRE_HELMIFY_HOOK="pre_helmify_hook_${CHART}"
    if declare -f "$PRE_HELMIFY_HOOK" > /dev/null; then
      echo "Calling pre-helmify hook function: $PRE_HELMIFY_HOOK"
      (cd "${SCRIPT_DIR}" && "$PRE_HELMIFY_HOOK")
    else
      echo "No pre-helmify hook function found for chart: $CHART"
    fi

    helmify -vv --original-name -f "manifests/${CHART}" "${CHART}"
    mkdir -pv "${CHART_DIR}/${CHART}"
    cp -R "${CHART}"/* "${CHART_DIR}/${CHART}"

    PRE_COMMIT_HOOK="pre_commit_hook_${CHART}"
    if declare -f "$PRE_COMMIT_HOOK" > /dev/null; then
      echo "Calling pre-commit hook function: $PRE_COMMIT_HOOK"
      (cd "${SCRIPT_DIR}" && "$PRE_COMMIT_HOOK")
    else
      echo "No pre-commit hook function found for chart: $CHART"
    fi

    cd "${SCRIPT_DIR}" || exit 1

    # Update the chart versions/description
    DESCRIPTION=$(yq eval ".${CHART}.description" $VERSIONS_SRC)
    CHART_VERSION=$(yq eval ".${CHART}.chart" $VERSIONS_SRC)
    APP_VERSION=$(yq eval ".${CHART}.application" $VERSIONS_SRC)
    yq e -i ".description = \"${DESCRIPTION}\"" "${CHART_DIR}/${CHART}/Chart.yaml"
    yq e -i ".version = \"${CHART_VERSION}\"" "${CHART_DIR}/${CHART}/Chart.yaml"
    yq e -i ".appVersion = \"${APP_VERSION}\"" "${CHART_DIR}/${CHART}/Chart.yaml"

    if [[ "$IS_GITHUB_CI" == true ]]; then
      git add -v "${CHART_DIR}/${CHART}"
      git diff --quiet && git diff --staged --quiet || git commit -m "Build ${CHART} helmchart for commit ${COMMIT}"
    else
      echo "Skipping git operations in local environment"
    fi
  done

  for CHART in "${HANDWRITTEN_CHARTS[@]}"; do
    echo "Processing chart: $CHART"

    mkdir -pv "${CHART_DIR}/${CHART}"
    cp -R "${CHART_SRC_DIR}/${CHART}"/* "${CHART_DIR}/${CHART}"

    cd "${SCRIPT_DIR}" || exit 1

    PRE_COMMIT_HOOK="pre_commit_hook_${CHART}"
    if declare -f "$PRE_COMMIT_HOOK" > /dev/null; then
      echo "Calling pre-commit hook function: $PRE_COMMIT_HOOK"
      "$PRE_COMMIT_HOOK"
    else
      echo "No pre-commit hook function found for chart: $CHART"
    fi

    # Update the chart versions/description
    DESCRIPTION=$(yq eval ".${CHART}.description" $VERSIONS_SRC)
    CHART_VERSION=$(yq eval ".${CHART}.chart" $VERSIONS_SRC)
    APP_VERSION=$(yq eval ".${CHART}.application" $VERSIONS_SRC)
    yq e -i ".description = \"${DESCRIPTION}\"" "${CHART_DIR}/${CHART}/Chart.yaml"
    yq e -i ".version = \"${CHART_VERSION}\"" "${CHART_DIR}/${CHART}/Chart.yaml"
    yq e -i ".appVersion = \"${APP_VERSION}\"" "${CHART_DIR}/${CHART}/Chart.yaml"

    if [[ "$IS_GITHUB_CI" == true ]]; then
      git add -v "${CHART_DIR}/${CHART}/*"
      git diff --quiet && git diff --staged --quiet || git commit -m "Build ${CHART} helmchart for commit ${COMMIT}"
    else
      echo "Skipping git operations in local environment"
    fi
  done

  if [[ "$IS_GITHUB_CI" == true ]]; then
    for METACHART in "${META_CHARTS[@]}"; do
      echo "Processing meta-chart: $CHART"
      cd "${SCRIPT_DIR}" || exit 1

      # Get current version from Chart.yaml
      METACHART_CHART_VERSION=$(yq e '.version' "${CHART_DIR}/${METACHART}/Chart.yaml")
      METACHART_APP_VERSION=$(yq e '.appVersion' "${CHART_DIR}/${METACHART}/Chart.yaml")

      # Copy chart sources
      mkdir -pv "${CHART_DIR}/${METACHART}"
      cp -R "${CHART_SRC_DIR}/${METACHART}"/* "${CHART_DIR}/${METACHART}"

      # Update deps in meta chart
      for CHART in "${GENERATED_CHARTS[@]}" "${HANDWRITTEN_CHARTS[@]}"; do
        echo "Updating version in ${METACHART} chart for ${CHART}"
        cd "${SCRIPT_DIR}" || exit 1
        CHART_VERSION=$(yq e ".version" "${CHART_DIR}/${CHART}/Chart.yaml")
        export CHART
        export CHART_VERSION
        yq e -i '(.dependencies[] | select(.name == env(CHART)) | .version) = env(CHART_VERSION)' "${CHART_DIR}/${METACHART}/Chart.yaml"
      done

      echo "Bumping ${METACHART} version"
      # Increment patch version
      METACHART_NEW_CHART_VERSION=$(echo "$METACHART_CHART_VERSION" | awk -F. '{print $1"."$2"."$3+1}')
      if [ $? -ne 0 ] || [ -z "$METACHART_NEW_CHART_VERSION" ]; then
        echo "Error: Failed to increment chart version"
        exit 1
      fi
      METACHART_NEW_APP_VERSION=$(echo "$METACHART_APP_VERSION" | awk -F. '{print $1"."$2"."$3+1}')
      if [ $? -ne 0 ] || [ -z "$METACHART_NEW_APP_VERSION" ]; then
        echo "Error: Failed to increment app version"
        exit 1
      fi

      # Update version in Chart.yaml
      yq e -i '.version = "'"$METACHART_NEW_CHART_VERSION"'"' "${CHART_DIR}/${METACHART}/Chart.yaml"
      yq e -i '.appVersion = "'"$METACHART_NEW_APP_VERSION"'"' "${CHART_DIR}/${METACHART}/Chart.yaml"

      PRE_COMMIT_HOOK="pre_commit_hook_${METACHART}"
      if declare -f "$PRE_COMMIT_HOOK" > /dev/null; then
        echo "Calling pre-commit hook function: $PRE_COMMIT_HOOK"
        (cd "${SCRIPT_DIR}" && "$PRE_COMMIT_HOOK")
      else
        echo "No pre-commit hook function found for chart: $METACHART"
      fi

      echo "Adding ${METACHART} chart to git staged and committing"
      git add "${CHART_DIR}/${METACHART}/*"
      git restore "src/${METACHART}/Chart.yaml" || true
      git diff --quiet && git diff --staged --quiet || git commit -m "Bump version of ${METACHART} helmchart for commit ${COMMIT}"
    done
  else
    echo "Skipping git operations in local environment"
  fi

  if [[ "$IS_GITHUB_CI" == true ]]; then
    finalize_git_ci
  else
    echo "Skipping finalize_git_ci in local environment"
  fi
}

function finalize_git_ci() {
  if [[ "$IS_GITHUB_CI" != true ]]; then
    echo "Skipping finalize_git_ci in local environment"
    return
  fi

  cd "$SCRIPT_DIR" || exit 1
  echo "Updating gh-pages branch"
  cp -R "${CHART_DIR}" /tmp/charts
  git switch gh-pages
  mkdir -pv "${CHART_DIR}"
  cp -R /tmp/charts/* "${CHART_DIR}"/
  git add "${CHART_DIR}"/*
  git diff --quiet && git diff --staged --quiet || git commit -m "Update helmcharts on gh-pages branch for commit ${COMMIT}"
  git push

  echo "Git push main"
  git switch main
    
  # Find the newest semver tag with -build suffix
  local newest_tag
  # Get all tags, filter for semver format (vX.Y.Z-build or X.Y.Z-build), sort by version, get the latest
  newest_tag=$(git tag -l | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+-build' | sort -V | tail -n 1)
  
  if [[ -n "$newest_tag" ]]; then
    # Strip -build suffix if present
    local stripped_tag
    stripped_tag="${newest_tag%-build}"
    if [[ "$stripped_tag" != "$newest_tag" ]]; then
      echo "Applying tag $stripped_tag (stripped from $newest_tag)"
      git tag "$stripped_tag"
    else
      echo "Newest tag $newest_tag does not have -build suffix, no tag to apply"
    fi
  else
    echo "No semver tag found, skipping tag application"
  fi

  # Push tags along with main branch
  git push && git push --tags
}

function setup_git_ci() {
  if [[ "$IS_GITHUB_CI" != true ]]; then
    echo "Skipping setup_git_ci in local environment"
    return
  fi

  cd "$SCRIPT_DIR" || exit 1
  # git setup
  echo "Setup git"
  git config --global --add safe.directory "$(pwd)"
  git config user.name "${GITHUB_ACTOR}"
  git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
  git fetch
  git pull
}

function update_readme_gh_pages_branch() {
  if [[ "$IS_GITHUB_CI" != true ]]; then
    echo "Skipping update_readme_gh_pages_branch in local environment"
    return
  fi

  cd "$SCRIPT_DIR" || exit 1
  # update readme
  echo "Update readme"
  git switch main
  cp README.md /tmp/README.md
  git switch gh-pages
  cp -v /tmp/README.md README.md
  git add --verbose README.md
  git diff --quiet && git diff --staged --quiet || (git commit -m "Update README.md for commit ${COMMIT}" && git push)
  git switch main
}

function setup_npm_ci() {
  if [[ "$IS_GITHUB_CI" != true ]]; then
    echo "Skipping setup_npm_ci in local environment"
    return
  fi

  cd "$SCRIPT_DIR" || exit 1
  # npm install
  echo "Setup npm"
  echo "//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}" >> "${HOME}/.npmrc"
  git switch main
  npm ci
}

function pre_helmify_hook_operator() {
  yq e -i '(.spec.selector.matchLabels, .spec.template.metadata.labels, .spec.selector) |= with_entries(select(.key == "cdk8s.io/metadata.addr") | .key = "pm8s.io/operator")' dist/manifests/operator/pm8s-operator.yaml
  yq e -i '(.. | select(tag == "!!map" and has("pm8s.io/operator"))) |= (.["pm8s.io/operator"] = "true")' dist/manifests/operator/pm8s-operator.yaml
  yq e -i '(select(.kind == "Deployment" and .metadata.name == "pm8s-operator") | .spec.selector) |= {"matchLabels": {"pm8s.io/operator": "true"}}' dist/manifests/operator/pm8s-operator.yaml
}

function pre_helmify_hook_crds() {
  yq e -i '(.spec.selector.matchLabels, .spec.template.metadata.labels, .spec.selector) |= with_entries(select(.key == "cdk8s.io/metadata.addr") | .key = "pm8s.io/crds")' dist/manifests/crds/pm8s-crds.yaml
  yq e -i '(.. | select(tag == "!!map" and has("pm8s.io/crds"))) |= (.["pm8s.io/crds"] = "true")' dist/manifests/crds/pm8s-crds.yaml
}

main
