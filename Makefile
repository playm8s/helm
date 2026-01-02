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
	mkdir -pv charts
	cd src/pm8s-operator && make helmcharts
	cp -rv src/pm8s-operator/dist/charts/pm8s-operator charts/
	bash set-version.sh pm8s-operator
	git add -r charts
	git stash push -- charts
	git fetch
	git switch gh-pages
	git pull
	git stash apply
	git add -f charts/pm8s-operator/*
	git commit -am "Build helm chart for pm8s-operator version $$(yq eval '.pm8s-operator.chart' src/versions.yaml)"

git-finalize:
	chown -R 1001:1001 .
	git push
	git switch main
