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

helmcharts: operator

operator:
	git switch main
	cd src/pm8s-operator && make helmcharts
	mkdir -pv /tmp/charts
	mv src/pm8s-operator/dist/charts/pm8s-operator /tmp/charts/pm8s-operator
	cp src/versions.yaml /tmp
	bash set-version.sh pm8s-operator /tmp/charts /tmp/versions.yaml
	git switch gh-pages
	rm -rf charts/pm8s-operator
	cp -rv /tmp/charts/pm8s-operator charts/pm8s-operator
	echo "git diff:"
	git diff
	git add --verbose -f charts/pm8s-operator/**
	git commit -am "Build helm chart for pm8s-operator version $$(yq eval '.pm8s-operator.chart' /tmp/versions.yaml)"
	git switch main

git-finalize:
	chown -R 1001:1001 .
	git switch gh-pages
	git push
	git switch main
