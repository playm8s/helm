SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

all: clean git-setup helmcharts git-finalize

clean:
	rm -rf charts
	cd src/pm8s-operator && make clean

git-setup:
	git config --global --add safe.directory .
	git fetch
	git pull
	git config user.name "${GITHUB_ACTOR}"
	git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"

helmcharts: operator

operator:
	git switch main
	cd src/pm8s-operator && make helmcharts
	mkdir -pv /tmp/charts
	mv src/pm8s-operator/dist/charts/pm8s-operator /tmp/charts/pm8s-operator
	bash set-version.sh pm8s-operator /tmp/charts
	git switch gh-pages
	mkdir -pv charts
	rm -rf charts/pm8s-operator
	mv /tmp/charts/pm8s-operator charts/pm8s-operator
	git add charts/pm8s-operator/**
	git commit -am "Build helm chart for pm8s-operator version $$(yq eval '.pm8s-operator.chart' src/versions.yaml)"

git-finalize:
	chown -R 1001:1001 .
	git switch gh-pages
	git push
	git switch main
