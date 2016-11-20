
# Common parameters of create and run targets
define DOCKER_CONTAINER_PARAMETERS
-t \
--name $(DOCKER_NAME) \
--restart $(DOCKER_RESTART_POLICY) \
--ulimit memlock=$(ULIMIT_MEMLOCK) \
--ulimit nofile=$(ULIMIT_NOFILE) \
--ulimit nproc=$(ULIMIT_NPROC) \
--env "VARNISH_MAX_THREADS=$(VARNISH_MAX_THREADS)" \
--env "VARNISH_MIN_THREADS=$(VARNISH_MIN_THREADS)" \
--env "VARNISH_STORAGE=$(VARNISH_STORAGE)" \
--env "VARNISH_THREAD_TIMEOUT=$(VARNISH_THREAD_TIMEOUT)" \
--env "VARNISH_TTL=$(VARNISH_TTL)" \
--env "VARNISH_VCL_CONF=$(VARNISH_VCL_CONF)"
endef

DOCKER_PUBLISH := $(shell \
	if [[ $(DOCKER_PORT_MAP_TCP_80) != NULL ]]; then printf -- '--publish %s:80\n' $(DOCKER_PORT_MAP_TCP_80); fi; \
	if [[ $(DOCKER_PORT_MAP_TCP_8443) != NULL ]]; then printf -- '--publish %s:8443\n' $(DOCKER_PORT_MAP_TCP_8443); fi; \
)
