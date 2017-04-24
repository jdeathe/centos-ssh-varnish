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

# Custom shpec matcher
# Match a string with an Extended Regular Expression pattern.
function __shpec_matcher_egrep ()
{
	local pattern="${2:-}"
	local string="${1:-}"

	printf -- \
		'%s' \
		"${string}" \
	| grep -qE -- \
		"${pattern}" \
		-

	assert equal \
		"${?}" \
		0
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
	local container_port_80=""
	local container_port_8443=""
	local header_x_varnish=""
	local request_headers=""
	local request_response=""
	local varnish_logs=""
	local varnish_vcl_loaded_hash=""
	local varnish_vcl_source_hash=""

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

			it "Exposes port ${DOCKER_PORT_MAP_TCP_8443} (PROXY protocol for terminated HTTPS)."
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

		varnish_logs="$(
			docker exec -t \
				varnish.pool-1.1.1 \
				cat /var/log/varnish.log
		)"

		it "Runs varnishd with a maximum of 1000 worker threads in each pool."
			assert __shpec_matcher_egrep \
				"${varnish_logs}" \
				"[ ]+-p thread_pool_max=1000[^0-9]+"
		end

		it "Runs varnishd with a minimum of 50 worker threads in each pool."
			assert __shpec_matcher_egrep \
				"${varnish_logs}" \
				"[ ]+-p thread_pool_min=50[^0-9]+"
		end

		it "Will destroy threads in excess of 50, which have been idle for at least 120 seconds."
			assert __shpec_matcher_egrep \
				"${varnish_logs}" \
				"[ ]+-p thread_pool_timeout=120[^0-9]+"
		end

		it "Sets a 120 second default TTL when not assigned by a backend or VCL."
			assert __shpec_matcher_egrep \
				"${varnish_logs}" \
				"[ ]+-t 120[^0-9]+"
		end

		it "Sets the default storage backend to file based with a size of 1G."
			assert __shpec_matcher_egrep \
				"${varnish_logs}" \
				"[ ]+-s file,\/var\/lib\/varnish\/varnish_storage\.bin,1G"
		end

		it "Loads the VCL file /etc/varnish/docker-default.vcl."
			assert __shpec_matcher_egrep \
				"${varnish_logs}" \
				"[ ]+-f \/etc\/varnish\/docker-default\.vcl"

			it "The loaded VCL file matches the source file."
				varnish_vcl_loaded_hash="$(
					docker exec \
						varnish.pool-1.1.1 \
						varnishadm vcl.show -v boot \
					| sed -n '/\/\/ VCL\.SHOW/,/\/\/ VCL\.SHOW/p' \
					| sed \
						-e '/\/\/ VCL.SHOW.*/d' \
						-e '/^$/d' \
						-e '/#/d' \
					| openssl sha1
				)"

				varnish_vcl_source_hash="$(
					sed -n \
						-e '/vcl/,$p' \
						etc/services-config/varnish/docker-default.vcl \
					| sed \
						-e '/^$/d' \
						-e '/#/d' \
					| openssl sha1
				)"

				assert equal \
					"${varnish_vcl_loaded_hash}" \
					"${varnish_vcl_source_hash}"
			end
		end

		it "Responds with a X-Varnish header to HTTP requests (port ${container_port_80})."
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

			it "Returns a cache hit when Cookies, excluding PHPSESSID OR app-session, are sent in the request."
				header_x_varnish="$(
					curl -sI \
						-H "Host: ${backend_hostname}" \
						-b "key_1=data_1; key_2=data_2" \
						http://127.0.0.1:${container_port_80}/ \
					| grep '^X-Varnish: ' \
					| cut -c 12- \
					| tr -d '\r'
				)"

				assert __shpec_matcher_egrep \
					"${header_x_varnish}" \
					"^[0-9]+ [0-9]+$"
			end

			it "Returns a cache pass when the Cookie PHPSESSID OR app-session is sent in the request."
				header_x_varnish="$(
					curl -sI \
						-H "Host: ${backend_hostname}" \
						-b "key_1=data_1; PHPSESSID=data_2" \
						http://127.0.0.1:${container_port_80}/ \
					| grep '^X-Varnish: ' \
					| cut -c 12- \
					| tr -d '\r'
				)"

				assert __shpec_matcher_egrep \
					"${header_x_varnish}" \
					"^[0-9]+$"
			end

			it "Returns the backend's HTML document contents."
				curl -s \
					-H "Host: ${backend_hostname}" \
					http://127.0.0.1:${container_port_80}/ \
				| grep -q '{{BODY}}'

				request_response="${?}"

				assert equal \
					"${request_response}" \
					0
			end
		end

		it "Responds with a X-Varnish header for PROXY protocol requests (port ${container_port_8443})."
			printf -v \
				request_headers \
				-- 'Host: %s\n%s' \
				"${backend_hostname}" \
				"Connection: close"

			header_x_varnish="$(
				expect test/telnet-proxy-tcp4.exp \
					127.0.0.2 \
					127.0.0.1 \
					${container_port_8443} \
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
						${container_port_8443} \
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

			it "Returns a cache hit when Cookies, excluding PHPSESSID OR app-session, are sent in the request."
				printf -v \
					request_headers \
					-- 'Host: %s\n%s\n%s' \
					"${backend_hostname}" \
					"Cookie: key_1=data_1; key_2=data_2" \
					"Connection: close"

				header_x_varnish="$(
					expect test/telnet-proxy-tcp4.exp \
						127.0.0.2 \
						127.0.0.1 \
						${container_port_8443} \
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

			it "Returns a cache pass when the Cookie PHPSESSID OR app-session is sent in the request."
				printf -v \
					request_headers \
					-- 'Host: %s\n%s\n%s' \
					"${backend_hostname}" \
					"Cookie: key_1=data_1; app-session=data_2" \
					"Connection: close"

				header_x_varnish="$(
					expect test/telnet-proxy-tcp4.exp \
						127.0.0.2 \
						127.0.0.1 \
						${container_port_8443} \
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
			end

			it "Returns the backend's HTML document contents."
				printf -v \
					request_headers \
					-- 'Host: %s\n%s' \
					"${backend_hostname}" \
					"Connection: close"

				expect test/telnet-proxy-tcp4.exp \
					127.0.0.2 \
					127.0.0.1 \
					${container_port_8443} \
					'GET / HTTP/1.1' "${request_headers}" \
					| sed -En '/^HTTP\/[0-9\.]+ [0-9]+/,$p' \
					| sed '/Connection closed by foreign host./d' \
					| grep -q '{{BODY}}'

				request_response="${?}"

				assert equal \
					"${request_response}" \
					0
			end
		end

		it "Returns the backend's HTML document contents with the backend offline for HTTP requests (port ${container_port_80})."
			docker stop \
				${backend_name} \
			&> /dev/null

			curl -s \
				-H "Host: ${backend_hostname}" \
				http://127.0.0.1:${container_port_80}/ \
			| grep -q '{{BODY}}'

			request_response="${?}"

			assert equal \
				"${request_response}" \
				0

			it "Returns the backend's HTML document contents with the backend offline for PROXY protocol requests (port ${container_port_8443})."
				expect test/telnet-proxy-tcp4.exp \
					127.0.0.2 \
					127.0.0.1 \
					${container_port_8443} \
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

		__terminate_container \
			varnish.pool-1.1.1 \
		&> /dev/null
	end

	trap - \
		INT TERM EXIT
}

function test_custom_configuration ()
{
	local backend_network="bridge_t1"
	local container_port_80=""
	local varnish_logs=""
	local varnish_vcl_loaded_hash=""
	local varnish_vcl_source_hash=""

	trap "__terminate_container varnish.pool-1.1.1 &> /dev/null; __destroy; exit 1" \
		INT TERM EXIT

	describe "Customised Varnish configuration"
		__terminate_container \
			varnish.pool-1.1.1 \
		&> /dev/null

		it "Runs a Varnish container named varnish.pool-1.1.1 on port ${DOCKER_PORT_MAP_TCP_80}."
			docker run -d \
				--name varnish.pool-1.1.1 \
				--env "VARNISH_MAX_THREADS=5000" \
				--env "VARNISH_MIN_THREADS=100" \
				--env "VARNISH_THREAD_TIMEOUT=300" \
				--env "VARNISH_STORAGE=malloc,256M" \
				--env "VARNISH_TTL=600" \
				--env "VARNISH_VCL_CONF=dmNsIDQuMDsKCmltcG9ydCBkaXJlY3RvcnM7CmltcG9ydCBzdGQ7CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgSGVhbHRoY2hlY2sgcHJvYmUgKGJhc2ljKQojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCnByb2JlIGhlYWx0aGNoZWNrIHsKCS5pbnRlcnZhbCA9IDVzOwoJLnRpbWVvdXQgPSAyczsKCS53aW5kb3cgPSA1OwoJLnRocmVzaG9sZCA9IDM7CgkuaW5pdGlhbCA9IDI7CgkuZXhwZWN0ZWRfcmVzcG9uc2UgPSAyMDA7CgkucmVxdWVzdCA9CgkJIkdFVCAvIEhUVFAvMS4xIgoJCSJIb3N0OiBsb2NhbGhvc3QubG9jYWxkb21haW4iCgkJIkNvbm5lY3Rpb246IGNsb3NlIgoJCSJVc2VyLUFnZW50OiBWYXJuaXNoIgoJCSJBY2NlcHQtRW5jb2Rpbmc6IGd6aXAsIGRlZmxhdGUiOwp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgSFRUUCBCYWNrZW5kcwojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCmJhY2tlbmQgaHR0cF8xIHsgLmhvc3QgPSAiaHR0cGRfMSI7IC5wb3J0ID0gIjgwIjsgLmZpcnN0X2J5dGVfdGltZW91dCA9IDMwMHM7IC5wcm9iZSA9IGhlYWx0aGNoZWNrOyB9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgSFRUUCAoSFRUUFMgVGVybWluYXRlZCkgQmFja2VuZHMKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQpiYWNrZW5kIHRlcm1pbmF0ZWRfaHR0cHNfMSB7IC5ob3N0ID0gImh0dHBkXzEiOyAucG9ydCA9ICI4NDQzIjsgLmZpcnN0X2J5dGVfdGltZW91dCA9IDMwMHM7IC5wcm9iZSA9IGhlYWx0aGNoZWNrOyB9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgRGlyZWN0b3JzCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0Kc3ViIHZjbF9pbml0IHsKCW5ldyBkaXJlY3Rvcl9odHRwID0gZGlyZWN0b3JzLnJvdW5kX3JvYmluKCk7CglkaXJlY3Rvcl9odHRwLmFkZF9iYWNrZW5kKGh0dHBfMSk7CgoJbmV3IGRpcmVjdG9yX3Rlcm1pbmF0ZWRfaHR0cHMgPSBkaXJlY3RvcnMucm91bmRfcm9iaW4oKTsKCWRpcmVjdG9yX3Rlcm1pbmF0ZWRfaHR0cHMuYWRkX2JhY2tlbmQodGVybWluYXRlZF9odHRwc18xKTsKfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIENsaWVudCBzaWRlCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0Kc3ViIHZjbF9yZWN2IHsKCWlmIChyZXEubWV0aG9kID09ICJQUkkiKSB7CgkJIyBSZWplY3QgU1BEWSBvciBIVFRQLzIuMCB3aXRoIE1ldGhvZCBOb3QgQWxsb3dlZAoJCXJldHVybiAoc3ludGgoNDA1KSk7Cgl9CgoJdW5zZXQgcmVxLmh0dHAuRm9yd2FyZGVkOwoJdW5zZXQgcmVxLmh0dHAuWC1Gb3J3YXJkZWQtUG9ydDsKCXVuc2V0IHJlcS5odHRwLlgtRm9yd2FyZGVkLVByb3RvOwoKCWlmIChzdGQucG9ydChzZXJ2ZXIuaXApID09IDg0NDMgfHwKCQlzdGQucG9ydChsb2NhbC5pcCkgPT0gODQ0MykgewoJCSMgU1NMIFRlcm1pbmF0ZWQgdXBzdHJlYW0gc28gaW5kY2F0ZSB0aGlzIHdpdGggYSBjdXN0b20gaGVhZGVyCgkJc2V0IHJlcS5odHRwLlgtRm9yd2FyZGVkLVBvcnQgPSAiNDQzIjsKCQlzZXQgcmVxLmh0dHAuWC1Gb3J3YXJkZWQtUHJvdG8gPSAiaHR0cHMiOwoJCXNldCByZXEuYmFja2VuZF9oaW50ID0gZGlyZWN0b3JfdGVybWluYXRlZF9odHRwcy5iYWNrZW5kKCk7Cgl9IGVsc2UgaWYgKHN0ZC5wb3J0KHNlcnZlci5pcCkgPT0gODAgfHwKCQlzdGQucG9ydChsb2NhbC5pcCkgPT0gODApIHsKCQkjIERlZmF1bHQgdG8gSFRUUAoJCXNldCByZXEuaHR0cC5YLUZvcndhcmRlZC1Qb3J0ID0gIjgwIjsKCQlzZXQgcmVxLmJhY2tlbmRfaGludCA9IGRpcmVjdG9yX2h0dHAuYmFja2VuZCgpOwoJfSBlbHNlIHsKCQlyZXR1cm4gKHN5bnRoKDQwMykpOwoJfQoKCSMgc2V0IHJlcS5odHRwLlgtVmFybmlzaC1HcmFjZSA9ICJub25lIjsKCglpZiAocmVxLm1ldGhvZCAhPSAiR0VUIiAmJgoJCXJlcS5tZXRob2QgIT0gIkhFQUQiICYmCgkJcmVxLm1ldGhvZCAhPSAiUFVUIiAmJgoJCXJlcS5tZXRob2QgIT0gIlBPU1QiICYmCgkJcmVxLm1ldGhvZCAhPSAiVFJBQ0UiICYmCgkJcmVxLm1ldGhvZCAhPSAiT1BUSU9OUyIgJiYKCQlyZXEubWV0aG9kICE9ICJERUxFVEUiKSB7CgkJIyBOb24tUkZDMjYxNiBvciBDT05ORUNUIHdoaWNoIGlzIHdlaXJkLgoJCXJldHVybiAocGlwZSk7Cgl9CgoJaWYgKHJlcS5tZXRob2QgIT0gIkdFVCIgJiYgCgkJcmVxLm1ldGhvZCAhPSAiSEVBRCIpIHsKCQkjIE9ubHkgZGVhbCB3aXRoIEdFVCBhbmQgSEVBRCBieSBkZWZhdWx0CgkJcmV0dXJuIChwYXNzKTsKCX0KCgkjIEhhbmRsZSBFeHBlY3QgcmVxdWVzdAoJaWYgKHJlcS5odHRwLkV4cGVjdCkgewoJCXJldHVybiAocGlwZSk7Cgl9CgoJIyBDYWNoZS1Db250cm9sCglpZiAocmVxLmh0dHAuQ2FjaGUtQ29udHJvbCB+ICIocHJpdmF0ZXxuby1jYWNoZXxuby1zdG9yZSkiKSB7CgkJcmV0dXJuIChwYXNzKTsKCX0KCgkjIENhY2hlIHN0YXRpYyBhc3NldHMKCWlmIChyZXEudXJsIH4gIlwuKGdpZnxwbmd8anBlP2d8aWNvfHN3Znxjc3N8anN8aHRtbD98dHh0KSQiKSB7CgkJdW5zZXQgcmVxLmh0dHAuQ29va2llOwoJCXJldHVybiAoaGFzaCk7Cgl9CgoJIyBSZW1vdmUgYWxsIGNvb2tpZXMgdGhhdCB3ZSBkb2Vzbid0IG5lZWQgdG8ga25vdyBhYm91dC4gZS5nLiAzcmQgcGFydHkgYW5hbHl0aWNzIGNvb2tpZXMKCWlmIChyZXEuaHR0cC5Db29raWUpIHsKCQlzZXQgcmVxLmh0dHAuQ29va2llID0gIjsiICsgcmVxLmh0dHAuQ29va2llOwoJCXNldCByZXEuaHR0cC5Db29raWUgPSByZWdzdWJhbGwocmVxLmh0dHAuQ29va2llLCAiOyArIiwgIjsiKTsKCQlzZXQgcmVxLmh0dHAuQ29va2llID0gcmVnc3ViYWxsKHJlcS5odHRwLkNvb2tpZSwgIjsoUEhQU0VTU0lEfGFwcC1zZXNzaW9uKT0iLCAiOyBcMT0iKTsKCQlzZXQgcmVxLmh0dHAuQ29va2llID0gcmVnc3ViYWxsKHJlcS5odHRwLkNvb2tpZSwgIjtbXiBdW147XSoiLCAiIik7CgkJc2V0IHJlcS5odHRwLkNvb2tpZSA9IHJlZ3N1YmFsbChyZXEuaHR0cC5Db29raWUsICJeWzsgXSt8WzsgXSskIiwgIiIpOwoKCQlpZiAocmVxLmh0dHAuQ29va2llID09ICIiKSB7CgkJCXVuc2V0IHJlcS5odHRwLkNvb2tpZTsKCQl9Cgl9CgoJIyBOb24tY2FjaGVhYmxlIHJlcXVlc3RzCglpZiAocmVxLmh0dHAuQXV0aG9yaXphdGlvbiB8fCAKCQlyZXEuaHR0cC5Db29raWUpIHsKCQlyZXR1cm4gKHBhc3MpOwoJfQoKCXJldHVybiAoaGFzaCk7Cn0KCnN1YiB2Y2xfaGFzaCB7CgloYXNoX2RhdGEocmVxLnVybCk7CgoJaWYgKHJlcS5odHRwLmhvc3QpIHsKCQloYXNoX2RhdGEocmVxLmh0dHAuaG9zdCk7Cgl9IGVsc2UgewoJCWhhc2hfZGF0YShzZXJ2ZXIuaXApOwoJfQoKCWlmIChyZXEuaHR0cC5YLUZvcndhcmRlZC1Qcm90bykgewoJCWhhc2hfZGF0YShyZXEuaHR0cC5YLUZvcndhcmRlZC1Qcm90byk7Cgl9CgoJcmV0dXJuIChsb29rdXApOwp9CgpzdWIgdmNsX2hpdCB7CglpZiAob2JqLnR0bCA+PSAwcykgewoJCXJldHVybiAoZGVsaXZlcik7Cgl9CgoJaWYgKHN0ZC5oZWFsdGh5KHJlcS5iYWNrZW5kX2hpbnQpICYmIAoJCW9iai50dGwgKyAxNXMgPiAwcykgewoJCSMgc2V0IHJlcS5odHRwLlgtVmFybmlzaC1HcmFjZSA9ICJub3JtYWwiOwoJCXJldHVybiAoZGVsaXZlcik7Cgl9IGVsc2UgaWYgKG9iai50dGwgKyBvYmouZ3JhY2UgPiAwcykgewoJCSMgc2V0IHJlcS5odHRwLlgtVmFybmlzaC1HcmFjZSA9ICJmdWxsIjsKCQlyZXR1cm4gKGRlbGl2ZXIpOwoJfQoKCXJldHVybiAobWlzcyk7Cn0KCnN1YiB2Y2xfZGVsaXZlciB7CgkjIHNldCByZXNwLmh0dHAuWC1WYXJuaXNoLUdyYWNlID0gcmVxLmh0dHAuWC1WYXJuaXNoLUdyYWNlOwoKCXJldHVybiAoZGVsaXZlcik7Cn0KCiMgRXJyb3JzOiA0MTMsIDQxNyAmIDUwMwpzdWIgdmNsX3N5bnRoIHsKCXNldCByZXNwLmh0dHAuQ29udGVudC1UeXBlID0gInRleHQvaHRtbDsgY2hhcnNldD11dGYtOCI7CglzZXQgcmVzcC5odHRwLlJldHJ5LUFmdGVyID0gIjUiOwoJc3ludGhldGljKCB7IjwhRE9DVFlQRSBodG1sPgo8aHRtbD4KCTxoZWFkPgoJCTx0aXRsZT5FcnJvcjwvdGl0bGU+CgkJPHN0eWxlPgoJCQlib2R5e2ZvbnQtZmFtaWx5OnNhbnMtc2VyaWY7Y29sb3I6IzY2NjtiYWNrZ3JvdW5kLWNvbG9yOiNmMWYxZjE7bWFyZ2luOjEyJTttYXgtd2lkdGg6NTAlO30KCQkJaDF7Y29sb3I6IzMzMztmb250LXNpemU6MS41ZW07Zm9udC13ZWlnaHQ6NDAwO3RleHQtdHJhbnNmb3JtOnVwcGVyY2FzZTt9CgkJPC9zdHlsZT4KCTwvaGVhZD4KCTxib2R5PgoJCTxoMT4ifSArIHJlc3Auc3RhdHVzICsgIiAiICsgcmVzcC5yZWFzb24gKyB7IjwvaDE+CgkJPHA+In0gKyByZXNwLnJlYXNvbiArIHsiPC9wPgoJCTxwPlhJRDogIn0gKyByZXEueGlkICsgeyI8L3A+Cgk8L2JvZHk+CjwvaHRtbD4KIn0gKTsKCXJldHVybiAoZGVsaXZlcik7Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBCYWNrZW5kCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0Kc3ViIHZjbF9iYWNrZW5kX3Jlc3BvbnNlIHsKCSMgS2VlcCBvYmplY3RzIGJleW9uZCB0aGVpciB0dGwKCXNldCBiZXJlc3AuZ3JhY2UgPSAxMmg7CgoJaWYgKGJlcmVzcC50dGwgPD0gMHMgfHwKCQliZXJlc3AuaHR0cC5TZXQtQ29va2llIHx8CgkJYmVyZXNwLmh0dHAuU3Vycm9nYXRlLWNvbnRyb2wgfiAibm8tc3RvcmUiIHx8CgkJKCAhIGJlcmVzcC5odHRwLlN1cnJvZ2F0ZS1Db250cm9sICYmIAoJCQliZXJlc3AuaHR0cC5DYWNoZS1Db250cm9sIH4gIihwcml2YXRlfG5vLWNhY2hlfG5vLXN0b3JlKSIpIHx8CgkJYmVyZXNwLmh0dHAuVmFyeSA9PSAiKiIpIHsKCQkjIE1hcmsgYXMgIkhpdC1Gb3ItUGFzcyIgZm9yIHRoZSBuZXh0IDIgbWludXRlcwoJCXNldCBiZXJlc3AudW5jYWNoZWFibGUgPSB0cnVlOwoJCXNldCBiZXJlc3AudHRsID0gMTIwczsKCQlyZXR1cm4gKGRlbGl2ZXIpOwoJfQoKCXJldHVybiAoZGVsaXZlcik7Cn0KCnN1YiB2Y2xfYmFja2VuZF9lcnJvciB7CglzZXQgYmVyZXNwLmh0dHAuQ29udGVudC1UeXBlID0gInRleHQvaHRtbDsgY2hhcnNldD11dGYtOCI7CglzZXQgYmVyZXNwLmh0dHAuUmV0cnktQWZ0ZXIgPSAiNSI7CglzeW50aGV0aWMoIHsiPCFET0NUWVBFIGh0bWw+CjxodG1sPgoJPHN0eWxlPgoJCWJvZHl7Zm9udC1mYW1pbHk6c2Fucy1zZXJpZjtjb2xvcjojNjY2O2JhY2tncm91bmQtY29sb3I6I2YxZjFmMTttYXJnaW46MTIlO21heC13aWR0aDo1MCU7fQoJCWgxe2NvbG9yOiMzMzM7Zm9udC1zaXplOjEuNWVtO2ZvbnQtd2VpZ2h0OjQwMDt0ZXh0LXRyYW5zZm9ybTp1cHBlcmNhc2U7fQoJPC9zdHlsZT4KCTxoZWFkPgoJCTx0aXRsZT5FcnJvcjwvdGl0bGU+Cgk8L2hlYWQ+Cgk8Ym9keT4KCQk8aDE+In0gKyBiZXJlc3Auc3RhdHVzICsgIiAiICsgYmVyZXNwLnJlYXNvbiArIHsiPC9oMT4KCQk8cD4ifSArIGJlcmVzcC5yZWFzb24gKyB7IjwvcD4KCQk8cD5YSUQ6ICJ9ICsgYmVyZXEueGlkICsgeyI8L3A+Cgk8L2JvZHk+CjwvaHRtbD4KIn0gKTsKCXJldHVybiAoZGVsaXZlcik7Cn0K" \
				--network ${backend_network} \
				--publish ${DOCKER_PORT_MAP_TCP_80}:80 \
				--publish ${DOCKER_PORT_MAP_TCP_8443}:8443 \
				--ulimit memlock=82000 \
				--ulimit nofile=131072 \
				--ulimit nproc=65535 \
				jdeathe/centos-ssh-varnish:latest \
			&> /dev/null

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

		sleep ${BOOTSTRAP_BACKOFF_TIME}

		varnish_logs="$(
			docker exec -t \
				varnish.pool-1.1.1 \
				cat /var/log/varnish.log
		)"

		it "Runs varnishd with a maximum of 5000 worker threads in each pool."
			assert __shpec_matcher_egrep \
				"${varnish_logs}" \
				"[ ]+-p thread_pool_max=5000[^0-9]+"
		end

		it "Runs varnishd with a minimum of 100 worker threads in each pool."
			assert __shpec_matcher_egrep \
				"${varnish_logs}" \
				"[ ]+-p thread_pool_min=100[^0-9]+"
		end

		it "Will destroy threads in excess of 100, which have been idle for at least 300 seconds."
			assert __shpec_matcher_egrep \
				"${varnish_logs}" \
				"[ ]+-p thread_pool_timeout=300[^0-9]+"
		end

		it "Sets a 600 second default TTL when not assigned by a backend or VCL."
			assert __shpec_matcher_egrep \
				"${varnish_logs}" \
				"[ ]+-t 600[^0-9]+"
		end

		it "Sets the default storage backend to memory based with a size of 256M."
			assert __shpec_matcher_egrep \
				"${varnish_logs}" \
				"[ ]+-s malloc,256M"
		end

		it "Loads the VCL file /etc/varnish/docker-default.vcl."
			assert __shpec_matcher_egrep \
				"${varnish_logs}" \
				"[ ]+-f \/etc\/varnish\/docker-default\.vcl"

			it "The loaded VCL file matches the source file."
				varnish_vcl_loaded_hash="$(
					docker exec \
						varnish.pool-1.1.1 \
						varnishadm vcl.show -v boot \
					| sed -n '/\/\/ VCL\.SHOW/,/\/\/ VCL\.SHOW/p' \
					| sed \
						-e '/\/\/ VCL.SHOW.*/d' \
						-e '/^$/d' \
						-e '/#/d' \
					| openssl sha1
				)"

				varnish_vcl_source_hash="$(
					sed -n \
						-e '/vcl/,$p' \
						test/fixture/varnish/etc/varnish/docker-default.vcl \
					| sed \
						-e '/^$/d' \
						-e '/#/d' \
					| openssl sha1
				)"

				assert equal \
					"${varnish_vcl_loaded_hash}" \
					"${varnish_vcl_source_hash}"
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
	test_custom_configuration
	__destroy
end
