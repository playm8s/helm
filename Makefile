SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

all:
	echo "no-op"

ci: clean git-setup helmcharts finalize

clean:
	rm -rf charts
	cd src/operator && make clean

git-setup:
	git config --global --add safe.directory .
	git config user.name "${GITHUB_ACTOR}"
	git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
	git fetch
	git pull

helmcharts: operator

operator:
	git switch main
	cd src/operator && make ci
	mkdir -pv /tmp/charts
	mv src/operator/dist/charts/operator /tmp/charts/operator
	cp src/versions.yaml /tmp
	bash set-version.sh operator /tmp/charts /tmp/versions.yaml
	git switch gh-pages
	rm -rf charts/operator
	mkdir -pv charts/operator
	cp -rv /tmp/charts/operator/. charts/operator/.
	echo "git diff:"
	git diff
	git add --verbose -f charts/operator/**
	git commit -am "Build helm chart for pm8s/operator version $$(yq eval '.operator.chart' /tmp/versions.yaml)"
	git switch main

finalize:
	chown -R 1001:1001 .
