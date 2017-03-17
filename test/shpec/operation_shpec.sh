readonly BOOTSTRAP_BACKOFF_TIME=3
readonly TEST_DIRECTORY="test"

# These should ideally be a static value but hosts might be using this port so 
# need to allow for alternatives.
DOCKER_PORT_MAP_TCP_22="${DOCKER_PORT_MAP_TCP_22:-NULL}"
DOCKER_PORT_MAP_TCP_80="${DOCKER_PORT_MAP_TCP_80:-8000}"
DOCKER_PORT_MAP_TCP_8443="${DOCKER_PORT_MAP_TCP_8443:-8443}"

function docker_terminate_container ()
{
	local CONTAINER="${1}"

	if docker ps -aq \
		--filter "name=${CONTAINER}" \
		--filter "status=paused" &> /dev/null; then
		docker unpause ${CONTAINER} &> /dev/null
	fi

	if docker ps -aq \
		--filter "name=${CONTAINER}" \
		--filter "status=running" &> /dev/null; then
		docker stop ${CONTAINER} &> /dev/null
	fi

	if docker ps -aq \
		--filter "name=${CONTAINER}" &> /dev/null; then
		docker rm -vf ${CONTAINER} &> /dev/null
	fi
}

function test_setup ()
{
	:
}

if [[ ! -d ${TEST_DIRECTORY} ]]; then
	printf -- \
		"ERROR: Please run from the project root.\n" \
		>&2
	exit 1
fi

describe "jdeathe/centos-ssh-varnish:latest"
	test_setup

	describe "Basic Varnish operations"
		trap "docker_terminate_container varnish.pool-1.1.1 &> /dev/null; exit 1" \
			INT TERM EXIT

		docker_terminate_container \
			varnish.pool-1.1.1 \
		&> /dev/null

		it "Runs a Varnish container named varnish.pool-1.1.1 on port ${DOCKER_PORT_MAP_TCP_80}."
			local container_hostname=""
			local container_port_80=""

			docker run -d \
				--name varnish.pool-1.1.1 \
				--publish ${DOCKER_PORT_MAP_TCP_80}:80 \
				--publish ${DOCKER_PORT_MAP_TCP_8443}:8443 \
				jdeathe/centos-ssh-varnish:latest \
			&> /dev/null

			container_hostname="$(
				docker exec \
					varnish.pool-1.1.1 \
					hostname
			)"

			container_port_80="$(
				docker port \
					varnish.pool-1.1.1 \
					80/tcp
			)"
			container_port_80=${container_port_80##*:}

			if [[ ${DOCKER_PORT_MAP_TCP_80} == 0 ]] \
				|| [[ -z ${DOCKER_PORT_MAP_TCP_80} ]]; then
				assert gt \
					"${container_port_80}" \
					"30000"
			else
				assert equal \
					"${container_port_80}" \
					"${DOCKER_PORT_MAP_TCP_80}"
			fi
		end

		docker_terminate_container \
			varnish.pool-1.1.1 \
		&> /dev/null

		trap - \
			INT TERM EXIT
	end
end
