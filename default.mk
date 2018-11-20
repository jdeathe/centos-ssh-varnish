
# Common parameters of create and run targets
define DOCKER_CONTAINER_PARAMETERS
--tty \
--name $(DOCKER_NAME) \
--restart $(DOCKER_RESTART_POLICY) \
--sysctl "net.core.somaxconn=$(SYSCTL_NET_CORE_SOMAXCONN)" \
--sysctl "net.ipv4.ip_local_port_range=$(SYSCTL_NET_IPV4_IP_LOCAL_PORT_RANGE)" \
--sysctl "net.ipv4.route.flush=$(SYSCTL_NET_IPV4_ROUTE_FLUSH)" \
--ulimit "memlock=$(ULIMIT_MEMLOCK)" \
--ulimit "nofile=$(ULIMIT_NOFILE)" \
--ulimit "nproc=$(ULIMIT_NPROC)" \
--env "VARNISH_AUTOSTART_VARNISHD_WRAPPER=$(VARNISH_AUTOSTART_VARNISHD_WRAPPER)" \
--env "VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER=$(VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER)" \
--env "VARNISH_MAX_THREADS=$(VARNISH_MAX_THREADS)" \
--env "VARNISH_MIN_THREADS=$(VARNISH_MIN_THREADS)" \
--env "VARNISH_STORAGE=$(VARNISH_STORAGE)" \
--env "VARNISH_THREAD_TIMEOUT=$(VARNISH_THREAD_TIMEOUT)" \
--env "VARNISH_TTL=$(VARNISH_TTL)" \
--env "VARNISH_VARNISHNCSA_FORMAT=$(VARNISH_VARNISHNCSA_FORMAT)" \
--env "VARNISH_VCL_CONF=$(VARNISH_VCL_CONF)"
endef

DOCKER_PUBLISH := $(shell \
	if [[ $(DOCKER_PORT_MAP_TCP_80) != NULL ]]; then printf -- '--publish %s:80\n' $(DOCKER_PORT_MAP_TCP_80); fi; \
	if [[ $(DOCKER_PORT_MAP_TCP_8443) != NULL ]]; then printf -- '--publish %s:8443\n' $(DOCKER_PORT_MAP_TCP_8443); fi; \
)
