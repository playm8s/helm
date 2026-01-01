SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

all: clean helmcharts finalize

clean:
	rm -rf charts
	cd src/pm8s-operator && make clean

helmcharts: operator

operator:
	mkdir -pv charts
	cd src/pm8s-operator && make helmcharts
	cp -rv src/pm8s-operator/dist/charts/pm8s-operator charts/
	touch charts/pm8s-operator/.helmignore
	bash set-version.sh pm8s-operator

finalize:
	chown -R 1001:1001 .
