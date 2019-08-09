# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
DOCKER_IMAGE_NAME := centos-ssh-varnish
DOCKER_IMAGE_RELEASE_TAG_PATTERN := ^[1-2]\.[0-9]+\.[0-9]+$
DOCKER_IMAGE_TAG_PATTERN := ^(latest|[1-2]\.[0-9]+\.[0-9]+)$
DOCKER_USER := jdeathe
SHPEC_ROOT := test/shpec

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
DIST_PATH ?= ./dist
DOCKER_CONTAINER_OPTS ?=
DOCKER_IMAGE_TAG ?= latest
DOCKER_NAME ?= varnish.1
DOCKER_PORT_MAP_TCP_80 ?= 8000
DOCKER_PORT_MAP_TCP_8443 ?= 8500
DOCKER_RESTART_POLICY ?= always
NO_CACHE ?= false
RELOAD_SIGNAL ?= HUP
STARTUP_TIME ?= 4
SYSCTL_NET_CORE_SOMAXCONN ?= 1024
SYSCTL_NET_IPV4_IP_LOCAL_PORT_RANGE ?= 1024 65535
SYSCTL_NET_IPV4_ROUTE_FLUSH ?= 1
ULIMIT_MEMLOCK ?= 82000
ULIMIT_NOFILE ?= 131072
ULIMIT_NPROC ?= 9223372036854775807

# ------------------------------------------------------------------------------
# Application container configuration
# ------------------------------------------------------------------------------
ENABLE_VARNISHD_WRAPPER ?= true
ENABLE_VARNISHNCSA_WRAPPER ?= false
VARNISH_MAX_THREADS ?= 1000
VARNISH_MIN_THREADS ?= 50
VARNISH_OPTIONS ?=
VARNISH_STORAGE ?= file,/var/lib/varnish/varnish_storage.bin,1G
VARNISH_THREAD_TIMEOUT ?= 120
VARNISH_TTL ?= 120
VARNISH_VARNISHNCSA_FORMAT ?= %h %l %u %t \"%r\" %s %b \"%{Referer}i\" \"%{User-agent}i\"
VARNISH_VARNISHNCSA_OPTIONS ?=
VARNISH_VCL_CONF ?= /etc/varnish/docker-default.vcl
