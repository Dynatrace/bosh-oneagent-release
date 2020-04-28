linux_templates = $(wildcard jobs/dynatrace-oneagent/templates/*.erb)
windows_templates = $(wildcard jobs/dynatrace-oneagent-windows/templates/*.erb)

.PHONY: lint
lint:
	shellcheck -x jobs/dynatrace-oneagent/templates/*.erb

.PHONY: test
test:
	integration/linux/run-tests.sh

dev-bosh-oneagent-release.tgz: $(linux_templates) $(windows_templates)
	bosh create-release --force --tarball=dev-bosh-oneagent-release.tgz

dev-release: dev-bosh-oneagent-release.tgz

.PHONY: dump-runtime-config
dump-runtime-config:
	bosh config --type runtime --name dynatrace > dt-runtime-config.yaml

.PHONY: update-config
update-config:
	bosh update-config --type runtime --name dynatrace dt-runtime-config.yaml

.PHONY: clean
clean:
	rm dt-runtime-config.yaml dev-bosh-oneagent-release.tgz
