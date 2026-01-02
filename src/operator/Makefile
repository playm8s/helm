SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

all: clean npm-install helmcharts

clean:
	rm -rf dist
	rm -f src/*.js
	rm -rf src/manifests

npm-install:
	npm install

helmcharts: operator-helmify

operator-manifests:
	npm install && cd src && npx tsc --module nodenext --lib es2024 playm8s-operator.ts && node playm8s-operator.js
	yq e -i '(.spec.selector.matchLabels, .spec.template.metadata.labels, .spec.selector) |= with_entries(select(.key == "cdk8s.io/metadata.addr") | .key = "pm8s.io/operator")' dist/manifests/operator/pm8s-operator.yaml
	yq e -i '(.. | select(tag == "!!map" and has("pm8s.io/operator"))) |= (.["pm8s.io/operator"] = "true")' dist/manifests/operator/pm8s-operator.yaml

operator-helmify: operator-manifests
	mkdir -pv dist/charts
	cd dist/charts && helmify -r -v -f ../manifests/operator pm8s-operator
