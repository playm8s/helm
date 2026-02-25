SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

all:
	echo "no-op"

ci: git-setup npm-install-ci update-readme ci-helmcharts finalize

npm-install-ci:
	echo "//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}" | tee -a "${HOME}/.npmrc"
	git switch main
	npm ci
	git reset --hard

tsc:
	npx tsc

git-setup:
	git config --global --add safe.directory .
	git config user.name "${GITHUB_ACTOR}"
	git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
	git fetch
	git pull

update-readme:
	git switch main
	cp README.md /tmp/README.md
	git switch gh-pages
	cp -v /tmp/README.md README.md
	git add --verbose README.md
	git diff --quiet && git diff --staged --quiet || git commit -m "Update README.md for commit $$(git rev-parse --short --verify main)"
	git switch main

ci-helmcharts: ci-operator ci-crds ci-gameserver-csgo

# pm8s/operator
ci-operator:
	git switch main
	make operator-helmify
	mkdir -pv /tmp/charts
	mv dist/charts/operator /tmp/charts/operator
	cp versions.yaml /tmp
	bash set-version.sh operator /tmp/charts /tmp/versions.yaml
	git switch gh-pages
	rm -rf charts/operator
	mkdir -pv charts/operator
	cp -rv /tmp/charts/operator/. charts/operator/.
	git add --verbose -f charts/operator/**
	git diff --quiet && git diff --staged --quiet || git commit -m "Build helm chart for pm8s/operator version $$(yq eval '.operator.chart' /tmp/versions.yaml)"
	git switch main

operator-manifests: tsc
	cd dist && node playm8s-operator.mjs
	yq e -i '(.spec.selector.matchLabels, .spec.template.metadata.labels, .spec.selector) |= with_entries(select(.key == "cdk8s.io/metadata.addr") | .key = "pm8s.io/operator")' dist/manifests/operator/pm8s-operator.yaml
	yq e -i '(.. | select(tag == "!!map" and has("pm8s.io/operator"))) |= (.["pm8s.io/operator"] = "true")' dist/manifests/operator/pm8s-operator.yaml
operator-helmify: operator-manifests
	mkdir -pv dist/charts
	cd dist/charts && helmify -r -v -f ../manifests/operator operator
	find dist/charts/operator -type f -exec sed -i 's/pm8SOperator/pm8sOperator/g' {} +

# pm8s/crds
ci-crds:
	git switch main
	make crds-helmify
	mkdir -pv /tmp/charts
	mv dist/charts/crds /tmp/charts/crds
	cp versions.yaml /tmp
	bash set-version.sh crds /tmp/charts /tmp/versions.yaml
	git switch gh-pages
	rm -rf charts/crds
	mkdir -pv charts/crds
	cp -rv /tmp/charts/crds/. charts/crds/.
	git add --verbose -f charts/crds/**
	git diff --quiet && git diff --staged --quiet || git commit -m "Build helm chart for pm8s/crds version $$(yq eval '.crds.chart' /tmp/versions.yaml)"
	git switch main

crds-manifests: tsc
	cd dist && node playm8s-crds.mjs
	yq e -i '(.spec.selector.matchLabels, .spec.template.metadata.labels, .spec.selector) |= with_entries(select(.key == "cdk8s.io/metadata.addr") | .key = "pm8s.io/crds")' dist/manifests/crds/pm8s-crds.yaml
	yq e -i '(.. | select(tag == "!!map" and has("pm8s.io/crds"))) |= (.["pm8s.io/crds"] = "true")' dist/manifests/crds/pm8s-crds.yaml
crds-helmify: crds-manifests
	mkdir -pv dist/charts
	cd dist/charts && helmify -r -v -f ../manifests/crds crds
	find dist/charts/crds -type f -exec sed -i 's/pm8SCrdJob/pm8sCrdJob/g' {} +

# pm8s/gameserver-csgo
ci-gameserver-csgo:
	git switch main
	mkdir -pv /tmp/charts
	cp -r src/charts/gameserver-csgo /tmp/charts/gameserver-csgo
	cp versions.yaml /tmp
	bash set-version.sh gameserver-csgo /tmp/charts /tmp/versions.yaml
	git switch gh-pages
	rm -rf charts/gameserver-csgo
	mkdir -pv charts/gameserver-csgo
	cp -rv /tmp/charts/gameserver-csgo/. charts/gameserver-csgo/.
	git add --verbose -f charts/gameserver-csgo/**
	git diff --quiet && git diff --staged --quiet || git commit -am "Build helm chart for pm8s/gameserver-csgo version $$(yq eval '.gameserver-csgo.chart' /tmp/versions.yaml)"
	git switch main
	cp -rv /tmp/charts/gameserver-csgo/. src/charts/gameserver-csgo/.
	git add --verbose -f src/charts/gameserver-csgo/**
	git diff --quiet && git diff --staged --quiet || git commit -m "Update helm chart for pm8s/gameserver-csgo version $$(yq eval '.gameserver-csgo.chart' /tmp/versions.yaml)"

finalize:
	chown -R 1001:1001 .
	git switch main
	git push
	git switch gh-pages
	git push

update-libraries:
	npm install --save @playm8s/crds@latest
