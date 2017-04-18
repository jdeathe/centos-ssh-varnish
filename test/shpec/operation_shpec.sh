readonly BOOTSTRAP_BACKOFF_TIME=3
readonly TEST_DIRECTORY="test"

# These should ideally be a static value but hosts might be using this port so 
# need to allow for alternatives.
DOCKER_PORT_MAP_TCP_22="${DOCKER_PORT_MAP_TCP_22:-NULL}"
DOCKER_PORT_MAP_TCP_80="${DOCKER_PORT_MAP_TCP_80:-8000}"
DOCKER_PORT_MAP_TCP_8443="${DOCKER_PORT_MAP_TCP_8443:-8443}"

function __destroy ()
{
	local backend_alias="httpd_1"
	local backend_name="apache-php.pool-1.1.1"
	local backend_network="bridge_t1"

	# Destroy the backend container
	__terminate_container \
		${backend_name} \
		&> /dev/null

	# Destroy the bridge network
	if [ -n $(docker network ls -q -f name="${backend_network}") ]; then
		docker network rm \
			${backend_network} \
			&> /dev/null
	fi
}

# Custom shpec matcher
# Match a string with an Extended Regular Expression patten.
function __shpec_matcher_egrep ()
{
	local pattern="${2:-}"
	local string="${1:-}"

	printf "%s" "${string}" \
		| grep -qE "${pattern}" -

	assert equal \
		"${?}" \
		0
}

function __setup ()
{
	local backend_alias="httpd_1"
	local backend_name="apache-php.pool-1.1.1"
	local backend_network="bridge_t1"

	# Create the bridge network
	if [ -z $(docker network ls -q -f name="${backend_network}") ]; then
		docker network create \
			--driver bridge \
			${backend_network} \
			&> /dev/null
	fi

	# Create the backend container
	__terminate_container \
		${backend_name} \
		&> /dev/null
	docker run \
		--detach \
		--name ${backend_name} \
		--network ${backend_network} \
		--network-alias ${backend_alias} \
		--volume ${PWD}/test/fixture/apache/var/www/public_html:/opt/app/public_html:ro \
		jdeathe/centos-ssh-apache-php:2.1.1 \
		&> /dev/null
}

function __terminate_container ()
{
	local container="${1}"

	if docker ps -aq \
		--filter "name=${container}" \
		--filter "status=paused" &> /dev/null; then
		docker unpause ${container} &> /dev/null
	fi

	if docker ps -aq \
		--filter "name=${container}" \
		--filter "status=running" &> /dev/null; then
		docker stop ${container} &> /dev/null
	fi

	if docker ps -aq \
		--filter "name=${container}" &> /dev/null; then
		docker rm -vf ${container} &> /dev/null
	fi
}

function test_basic_operations ()
{
	local backend_hostname="localhost.localdomain"
	local backend_name="apache-php.pool-1.1.1"
	local backend_network="bridge_t1"
	local container_hostname=""
	local container_port_80=""
	local container_port_8443=""
	local header_x_varnish=""
	local request_headers=""
	local request_response

	trap "__terminate_container varnish.pool-1.1.1 &> /dev/null; __destroy; exit 1" \
		INT TERM EXIT

	describe "Basic Varnish operations"
		__terminate_container \
			varnish.pool-1.1.1 \
		&> /dev/null

		it "Runs a Varnish container named varnish.pool-1.1.1 on port ${DOCKER_PORT_MAP_TCP_80}."
			docker run -d \
				--name varnish.pool-1.1.1 \
				--network ${backend_network} \
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
			
			it "Also exposes port ${DOCKER_PORT_MAP_TCP_8443} (PROXY protocol for terminated HTTPS)."
				container_port_8443="$(
					docker port \
						varnish.pool-1.1.1 \
						8443/tcp
				)"
				container_port_8443=${container_port_8443##*:}

				if [[ ${DOCKER_PORT_MAP_TCP_8443} == 0 ]] \
					|| [[ -z ${DOCKER_PORT_MAP_TCP_8443} ]]; then
					assert gt \
						"${container_port_8443}" \
						"30000"
				else
					assert equal \
						"${container_port_8443}" \
						"${DOCKER_PORT_MAP_TCP_8443}"
				fi
			end
		end

		sleep ${BOOTSTRAP_BACKOFF_TIME}

		it "Responds with a X-Varnish header to HTTP requests (port ${DOCKER_PORT_MAP_TCP_80})."
			header_x_varnish="$(
				curl -sI \
					-H "Host: ${backend_hostname}" \
					http://127.0.0.1:${container_port_80}/ \
				| grep '^X-Varnish: ' \
				| cut -c 12- \
				| tr -d '\r'
			)"

			assert __shpec_matcher_egrep \
				"${header_x_varnish}" \
				"^[0-9]+$"

			it "Responds with a X-Varnish header containing both the ID of the current request and the ID of the request that populated the cache."
				header_x_varnish="$(
					curl -sI \
						-H "Host: ${backend_hostname}" \
						http://127.0.0.1:${container_port_80}/ \
					| grep '^X-Varnish: ' \
					| cut -c 12- \
					| tr -d '\r'
				)"

				assert __shpec_matcher_egrep \
					"${header_x_varnish}" \
					"^[0-9]+ [0-9]+$"
			end

			it "Returns the HTML document containing the {{BODY}} string."
				curl -s \
					-H "Host: ${backend_hostname}" \
					http://127.0.0.1:${container_port_80}/ \
				| grep -q '{{BODY}}'

				request_response="${?}"

				assert equal \
					"${request_response}" \
					0

				it "Returns the HTML document containing the {{BODY}} string with the backend offline."
					docker stop \
						${backend_name} \
						&> /dev/null

					curl -s \
						-H "Host: ${backend_hostname}" \
						http://127.0.0.1:${container_port_80}/ \
					| grep -q '{{BODY}}'

					request_response="${?}"

					docker start \
						${backend_name} \
						&> /dev/null

					assert equal \
						"${request_response}" \
						0
				end
			end
		end

		sleep ${BOOTSTRAP_BACKOFF_TIME}

		it "Responds with a X-Varnish header for PROXY protocol requests (port ${DOCKER_PORT_MAP_TCP_8443})."
			printf -v \
				request_headers \
				-- 'Host: %s\n%s' \
				"${backend_hostname}" \
				"Connection: close"

			header_x_varnish="$(
				expect test/telnet-proxy-tcp4.exp \
					127.0.0.2 \
					127.0.0.1 \
					${DOCKER_PORT_MAP_TCP_8443} \
					'HEAD / HTTP/1.1' "${request_headers}" \
					| sed -En '/^HTTP\/[0-9\.]+ [0-9]+/,$p' \
					| sed '/Connection closed by foreign host./d' \
					| grep '^X-Varnish: ' \
					| cut -c 12- \
					| tr -d '\r'
			)"

			assert __shpec_matcher_egrep \
				"${header_x_varnish}" \
				"^[0-9]+$"

			it "Responds with a X-Varnish header containing both the ID of the current request and the ID of the request that populated the cache."
				header_x_varnish="$(
					expect test/telnet-proxy-tcp4.exp \
						127.0.0.2 \
						127.0.0.1 \
						${DOCKER_PORT_MAP_TCP_8443} \
						'HEAD / HTTP/1.1' "${request_headers}" \
						| sed -En '/^HTTP\/[0-9\.]+ [0-9]+/,$p' \
						| sed '/Connection closed by foreign host./d' \
						| grep '^X-Varnish: ' \
						| cut -c 12- \
						| tr -d '\r'
				)"

				assert __shpec_matcher_egrep \
					"${header_x_varnish}" \
					"^[0-9]+ [0-9]+$"
			end
			
			it "Returns the HTML document containing the {{BODY}} string."
				expect test/telnet-proxy-tcp4.exp \
					127.0.0.2 \
					127.0.0.1 \
					${DOCKER_PORT_MAP_TCP_8443} \
					'GET / HTTP/1.1' "${request_headers}" \
					| sed -En '/^HTTP\/[0-9\.]+ [0-9]+/,$p' \
					| sed '/Connection closed by foreign host./d' \
					| grep -q '{{BODY}}'

				request_response="${?}"

				assert equal \
					"${request_response}" \
					0

				it "Returns the HTML document containing the {{BODY}} string with the backend offline."
					docker stop \
						${backend_name} \
						&> /dev/null

					expect test/telnet-proxy-tcp4.exp \
						127.0.0.2 \
						127.0.0.1 \
						${DOCKER_PORT_MAP_TCP_8443} \
						'GET / HTTP/1.1' "${request_headers}" \
						| sed -En '/^HTTP\/[0-9\.]+ [0-9]+/,$p' \
						| sed '/Connection closed by foreign host./d' \
						| grep -q '{{BODY}}'

					request_response="${?}"

					docker start \
						${backend_name} \
						&> /dev/null

					assert equal \
						"${request_response}" \
						0
				end
			end
		end

		__terminate_container \
			varnish.pool-1.1.1 \
		&> /dev/null
	end

	trap - \
		INT TERM EXIT
}

if [[ ! -d ${TEST_DIRECTORY} ]]; then
	printf -- \
		"ERROR: Please run from the project root.\n" \
		>&2
	exit 1
fi

describe "jdeathe/centos-ssh-varnish:latest"
	__setup
	test_basic_operations
	__destroy
end
