# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
DOCKER_USER := jdeathe
DOCKER_IMAGE_NAME := centos-ssh-varnish

# Tag validation patterns
DOCKER_IMAGE_TAG_PATTERN := ^(latest|(centos-[6-7])|(centos-(6-1|7-2).[0-9]+.[0-9]+))$
DOCKER_IMAGE_RELEASE_TAG_PATTERN := ^centos-(6-1|7-2).[0-9]+.[0-9]+$

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

# Docker image/container settings
DOCKER_CONTAINER_OPTS ?=
DOCKER_IMAGE_TAG ?= latest
DOCKER_NAME ?= varnish.pool-1.1.1
DOCKER_PORT_MAP_TCP_22 ?= NULL
DOCKER_PORT_MAP_TCP_80 ?= 80
DOCKER_PORT_MAP_TCP_8443 ?= 8443
DOCKER_RESTART_POLICY ?= always

# Docker build --no-cache parameter
NO_CACHE ?= false

# Directory path for release packages
DIST_PATH ?= ./dist

# ------------------------------------------------------------------------------
# Application container configuration
# ------------------------------------------------------------------------------
SSH_AUTHORIZED_KEYS ?=
SSH_AUTOSTART_SSHD ?= false
SSH_AUTOSTART_SSHD_BOOTSTRAP ?= false
SSH_CHROOT_DIRECTORY ?= %h
SSH_INHERIT_ENVIRONMENT ?= false
SSH_SUDO ?= ALL=(ALL) ALL
SSH_USER ?= app-admin
SSH_USER_FORCE_SFTP ?= false
SSH_USER_HOME ?= /home/%u
SSH_USER_ID ?= 500:500
SSH_USER_PASSWORD ?=
SSH_USER_PASSWORD_HASHED ?= false
SSH_USER_SHELL ?= /bin/bash
# ------------------------------------------------------------------------------
ULIMIT_MEMLOCK ?= 82000
ULIMIT_NOFILE ?= 131072
ULIMIT_NPROC ?= 9223372036854775807
VARNISH_ADMIN_LISTEN_ADDRESS ?= 127.0.0.1
VARNISH_ADMIN_LISTEN_PORT ?= 6082
VARNISH_LISTEN_ADDRESS ?= 0.0.0.0
VARNISH_LISTEN_PORT ?= 80,0.0.0.0:8443
VARNISH_MAX_THREADS ?= 1000
VARNISH_MIN_THREADS ?= 50
VARNISH_PIDFILE ?= /var/run/varnish.pid
VARNISH_SECRET_FILE ?= /etc/varnish/secret
VARNISH_STORAGE ?= file,/var/lib/varnish/varnish_storage.bin,1G
VARNISH_THREAD_TIMEOUT ?= 120
VARNISH_TTL ?= 120
VARNISH_VCL_CONF ?= /etc/varnish/docker-default.vcl
