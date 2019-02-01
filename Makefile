rel_name='my-release'
ns='default'
override=''
debug_fname='debug.out'
debug_ctnr_image='cosmintitei/bash-curl:4.4.12'
rand_str=`uuidgen | fold -w5 | head -n1 | awk '{print tolower($0)}'`


install: dry-run
	@helm install . --name $(rel_name) --namespace $(ns) --values $(override)

upgrade: init clean dep-build
	@helm upgrade $(rel_name) . --install --namespace $(ns) --values $(override)

lint:
	@helm lint .

render-all:
	@find ./templates -type f -name "*.yaml" \
		-exec helm template . -x {} \
		--name $(rel_name) \
		--namespace $(ns) \
		--values $(override) \;

init:
	@helm init -c

clean:
	@rm -f requirements.lock
	@rm -f charts/*.tgz

dep-update:
	@helm repo update

dep-build:
	@helm dependency build

dry-run: init clean dep-build
	@helm upgrade $(rel_name) . --install --namespace $(ns) --dry-run

debug: init clean dep-build
	@helm upgrade $(rel_name) . --install --namespace $(ns) --dry-run --debug > $(debug_fname)
	@echo "* Output has been saved into $(debug_fname)"

run-debug-ctnr:
	@kubectl run debug-$(rand_str) -n $(ns) --image=$(debug_ctnr_image) \
		--rm -ti --restart=Never --command -- bash

delete-purge:
	@helm delete --purge $(rel_name)

test:
	@helm test $(rel_name) || echo "errored"
	@sleep 2
	@echo ""
	@echo "* Tests output"
	@kubectl get pods -n $(ns) --sort-by=.status.startTime -o name \
		| grep "\-tests\-" \
		| tail -n1 \
		| xargs kubectl logs -n $(ns)
