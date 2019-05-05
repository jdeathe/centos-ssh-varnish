# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
readonly DOCKER_USER=jdeathe
readonly DOCKER_IMAGE_NAME=centos-ssh-varnish

# Tag validation patterns
readonly DOCKER_IMAGE_TAG_PATTERN='^(latest|centos-[6-7]|((1|2|centos-(6-1|7-2))\.[0-9]+\.[0-9]+))$'
readonly DOCKER_IMAGE_RELEASE_TAG_PATTERN='^(1|2|centos-(6-1|7-2))\.[0-9]+\.[0-9]+$'

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------

# Docker image/container settings
DOCKER_CONTAINER_OPTS="${DOCKER_CONTAINER_OPTS:-}"
DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-latest}"
DOCKER_NAME="${DOCKER_NAME:-varnish.1}"
DOCKER_PORT_MAP_TCP_80="${DOCKER_PORT_MAP_TCP_80:-8000}"
DOCKER_PORT_MAP_TCP_8443="${DOCKER_PORT_MAP_TCP_8443:-8500}"
DOCKER_RESTART_POLICY="${DOCKER_RESTART_POLICY:-always}"

# Docker build --no-cache parameter
NO_CACHE="${NO_CACHE:-false}"

# Directory path for release packages
DIST_PATH="${DIST_PATH:-./dist}"

# Number of seconds expected to complete container startup including bootstrap.
STARTUP_TIME="${STARTUP_TIME:-3}"

# Docker --sysctl settings
SYSCTL_NET_CORE_SOMAXCONN="${SYSCTL_NET_CORE_SOMAXCONN:-1024}"
SYSCTL_NET_IPV4_IP_LOCAL_PORT_RANGE="${SYSCTL_NET_IPV4_IP_LOCAL_PORT_RANGE:-1024 65535}"
SYSCTL_NET_IPV4_ROUTE_FLUSH="${SYSCTL_NET_IPV4_ROUTE_FLUSH:-1}"

# Docker --ulimit settings
ULIMIT_MEMLOCK="${ULIMIT_MEMLOCK:-82000}"
ULIMIT_NOFILE="${ULIMIT_NOFILE:-131072}"
ULIMIT_NPROC="${ULIMIT_NPROC:-9223372036854775807}"

# ETCD register service settings
REGISTER_ETCD_PARAMETERS="${REGISTER_ETCD_PARAMETERS:-}"
REGISTER_TTL="${REGISTER_TTL:-60}"
REGISTER_UPDATE_INTERVAL="${REGISTER_UPDATE_INTERVAL:-55}"

# ------------------------------------------------------------------------------
# Application container configuration
# ------------------------------------------------------------------------------
VARNISH_AUTOSTART_VARNISHD_WRAPPER="${VARNISH_AUTOSTART_VARNISHD_WRAPPER:-true}"
VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER="${VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER:-false}"
VARNISH_MAX_THREADS="${VARNISH_MAX_THREADS:-1000}"
VARNISH_MIN_THREADS="${VARNISH_MIN_THREADS:-50}"
VARNISH_OPTIONS=""
VARNISH_STORAGE="${VARNISH_STORAGE:-file,/var/lib/varnish/varnish_storage.bin,1G}"
VARNISH_THREAD_TIMEOUT="${VARNISH_THREAD_TIMEOUT:-120}"
VARNISH_TTL="${VARNISH_TTL:-120}"
VARNISH_VARNISHNCSA_FORMAT="${VARNISH_VARNISHNCSA_FORMAT:-"%h %l %u %t \"%r\" %s %b \"%{Referer}i\" \"%{User-agent}i\""}"
VARNISH_VARNISHNCSA_OPTIONS=""
VARNISH_VCL_CONF="${VARNISH_VCL_CONF:-/etc/varnish/docker-default.vcl}"
