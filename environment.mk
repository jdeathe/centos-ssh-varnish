# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
DOCKER_USER := jdeathe
DOCKER_IMAGE_NAME := centos-ssh-varnish
SHPEC_ROOT := test/shpec

# Tag validation patterns
DOCKER_IMAGE_TAG_PATTERN := ^(latest|centos-6|((1|centos-6-1)\.[0-9]+\.[0-9]+))$
DOCKER_IMAGE_RELEASE_TAG_PATTERN := ^(1|centos-6-1)\.[0-9]+\.[0-9]+$

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------

# Docker image/container settings
DOCKER_CONTAINER_OPTS ?=
DOCKER_IMAGE_TAG ?= latest
DOCKER_NAME ?= varnish.1
DOCKER_PORT_MAP_TCP_80 ?= 8000
DOCKER_PORT_MAP_TCP_8443 ?= 8500
DOCKER_RESTART_POLICY ?= always

# Docker build --no-cache parameter
NO_CACHE ?= false

# Directory path for release packages
DIST_PATH ?= ./dist

# Number of seconds expected to complete container startup including bootstrap.
STARTUP_TIME ?= 4

# Docker --sysctl settings
SYSCTL_NET_CORE_SOMAXCONN ?= 1024
SYSCTL_NET_IPV4_IP_LOCAL_PORT_RANGE ?= 1024 65535
SYSCTL_NET_IPV4_ROUTE_FLUSH ?= 1

# Docker --ulimit settings
ULIMIT_MEMLOCK ?= 82000
ULIMIT_NOFILE ?= 131072
ULIMIT_NPROC ?= 9223372036854775807

# ------------------------------------------------------------------------------
# Application container configuration
# ------------------------------------------------------------------------------
VARNISH_AUTOSTART_VARNISHD_WRAPPER ?= true
VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER ?= false
VARNISH_MAX_THREADS ?= 1000
VARNISH_MIN_THREADS ?= 50
VARNISH_OPTIONS ?=
VARNISH_STORAGE ?= file,/var/lib/varnish/varnish_storage.bin,1G
VARNISH_THREAD_TIMEOUT ?= 120
VARNISH_TTL ?= 120
VARNISH_VARNISHNCSA_FORMAT ?= %h %l %u %t \"%r\" %s %b \"%{Referer}i\" \"%{User-agent}i\"
VARNISH_VARNISHNCSA_OPTIONS ?=
VARNISH_VCL_CONF ?= /etc/varnish/docker-default.vcl
