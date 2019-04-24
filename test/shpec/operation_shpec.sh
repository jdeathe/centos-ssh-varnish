readonly STARTUP_TIME=2
readonly TEST_DIRECTORY="test"

# These should ideally be a static value but hosts might be using this port so 
# need to allow for alternatives.
DOCKER_PORT_MAP_TCP_80="${DOCKER_PORT_MAP_TCP_80:-8000}"
DOCKER_PORT_MAP_TCP_8443="${DOCKER_PORT_MAP_TCP_8443:-8443}"

function __destroy ()
{
	local -r backend_alias="httpd_1"
	local -r backend_name="apache-php.1"
	local -r backend_network="bridge_t1"

	# Destroy the backend container
	__terminate_container \
		${backend_name} \
	&> /dev/null

	# Destroy the bridge network
	if [[ -n $(docker network ls -q -f name="${backend_network}") ]]; then
		docker network rm \
			${backend_network} \
		&> /dev/null
	fi

	# Truncate cookie-jar
	:> ~/.curl_cookies
}

function __get_container_port ()
{
	local container="${1:-}"
	local port="${2:-}"
	local value=""

	value="$(
		docker port \
			${container} \
			${port}
	)"
	value=${value##*:}

	printf -- \
		'%s' \
		"${value}"
}

# container - Docker container name.
# counter - Timeout counter in seconds.
# process_pattern - Regular expression pattern used to match running process.
# ready_test - Command used to test if the service is ready.
function __is_container_ready ()
{
	local container="${1:-}"
	local counter=$(
		awk \
			-v seconds="${2:-10}" \
			'BEGIN { print 10 * seconds; }'
	)
	local process_pattern="${3:-}"
	local ready_test="${4:-true}"

	until (( counter == 0 )); do
		sleep 0.1

		if docker exec ${container} \
			bash -c "ps axo command \
				| grep -qE \"${process_pattern}\" \
				&& eval \"${ready_test}\"" \
			&> /dev/null
		then
			break
		fi

		(( counter -= 1 ))
	done

	if (( counter == 0 )); then
		return 1
	fi

	return 0
}

function __setup ()
{
	local -r backend_alias="httpd_1"
	local -r backend_name="apache-php.1"
	local -r backend_network="bridge_t1"
	local -r backend_release="3.1.1"

	# Create the bridge network
	if [[ -z $(docker network ls -q -f name="${backend_network}") ]]; then
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
		jdeathe/centos-ssh-apache-php:${backend_release} \
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
	local -r varnish_vcl_source_path="src/etc/varnish/docker-default.vcl"
	local -r backend_hostname="localhost.localdomain"
	local -r backend_name="apache-php.1"
	local -r backend_network="bridge_t1"
	local container_port_80=""
	local container_port_8443=""
	local header_x_varnish=""
	local phpsessid=""
	local request_headers=""
	local request_response=""
	local varnish_logs=""
	local varnish_parameter=""
	local varnish_vcl_loaded_hash=""
	local varnish_vcl_source_hash=""

	trap "__terminate_container varnish.1 &> /dev/null; \
		__destroy; \
		exit 1" \
		INT TERM EXIT

	describe "Basic Varnish operations"
		describe "Runs named container"
			__terminate_container \
				varnish.1 \
			&> /dev/null

			it "Can publish ${DOCKER_PORT_MAP_TCP_80}:80."
				docker run \
					--detach \
					--name varnish.1 \
					--network ${backend_network} \
					--publish ${DOCKER_PORT_MAP_TCP_80}:80 \
					--publish ${DOCKER_PORT_MAP_TCP_8443}:8443 \
					jdeathe/centos-ssh-varnish:latest \
				&> /dev/null

				container_port_80="$(
					__get_container_port \
						varnish.1 \
						80/tcp
				)"

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

			it "Can publish ${DOCKER_PORT_MAP_TCP_8443}:8443."
				container_port_8443="$(
					__get_container_port \
						varnish.1 \
						8443/tcp
				)"

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

		if ! __is_container_ready \
			varnish.1 \
			${STARTUP_TIME} \
			"/usr/sbin/varnishd " \
			"varnishadm vcl.show -v boot"
		then
			exit 1
		fi

		describe "Default initialisation"
			varnish_logs="$(
				docker logs \
					varnish.1 \
				2>&1
			)"

			varnish_parameters="$(
				docker exec -t \
					varnish.1 \
					varnishadm param.show
			)"

			# Runs varnishd with a maximum of 1000 worker threads in each pool.
			it "Sets thread_pool_max=1000."
				assert __shpec_matcher_egrep \
					"${varnish_parameters}" \
					"^thread_pool_max[ ]+1000[^0-9]+"
			end

			# Runs varnishd with a minimum of 50 worker threads in each pool.
			it "Sets thread_pool_min=50."
				assert __shpec_matcher_egrep \
					"${varnish_parameters}" \
					"^thread_pool_min[ ]+50[^0-9]+"
			end

			# Will destroy threads in excess of 50, which have been idle for at least 120 seconds.
			it "Sets thread_pool_timeout=120."
				assert __shpec_matcher_egrep \
					"${varnish_parameters}" \
					"^thread_pool_timeout[ ]+120[^0-9]+"
			end

			# Sets a 120 second default TTL when not assigned by a backend or VCL.
			it "Sets default_ttl=120."
				assert __shpec_matcher_egrep \
					"${varnish_parameters}" \
					"^default_ttl[ ]+120[^0-9]+"
			end

			# Sets the default storage backend to file based with a size of 1G.
			it "Sets a 1G file storage."
				assert __shpec_matcher_egrep \
					"${varnish_logs}" \
					"^storage : file,\/var\/lib\/varnish\/varnish_storage\.bin,1G"
			end

			describe "VCL file"
				it "Sets path to docker-default.vcl."
					assert __shpec_matcher_egrep \
						"${varnish_logs}" \
						"^vcl : \/etc\/varnish\/docker-default\.vcl"
				end

				it "Is unaltered."
					varnish_vcl_loaded_hash="$(
						docker exec \
							varnish.1 \
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
							"${varnish_vcl_source_path}" \
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
		end

		describe "Response to HTTP requests"
			it "Sets an X-Varnish header."
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
			end

			describe "X-Varnish response header"
				# Has both the ID of the current request and the ID of the request that populated the cache.
				it "Has 2 request IDs."
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

				describe "Request with 3rd party Cookie"
					it "Has a cache hit."
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
				end

				describe "Request with PHP session Cookie"
					# Initial request required to test cache
					curl -sI \
						-H "Host: ${backend_hostname}" \
						--cookie ~/.curl_cookies \
						--cookie-jar ~/.curl_cookies \
						http://127.0.0.1:${container_port_80}/session.php \
						&> /dev/null

					it "Has a cache pass."
						header_x_varnish="$(
							curl -sI \
								-H "Host: ${backend_hostname}" \
								--cookie ~/.curl_cookies \
								--cookie-jar ~/.curl_cookies \
								http://127.0.0.1:${container_port_80}/session.php \
							| grep '^X-Varnish: ' \
							| cut -c 12- \
							| tr -d '\r'
						)"

						assert __shpec_matcher_egrep \
							"${header_x_varnish}" \
							"^[0-9]+$"
					end
				end
			end

			it "Unsets the Via header."
				header_via="$(
					curl -sI \
						-H "Host: ${backend_hostname}" \
						http://127.0.0.1:${container_port_80}/ \
					| grep '^Via: ' \
					| tr -d '\r'
				)"

				assert equal \
					"${header_via}" \
					""
			end

			describe "Backend HTML content"
				it "Is unaltered."
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
		end

		describe "Response to PROXY protocol requests"
			it "Sets an X-Varnish header."
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
			end

			describe "X-Varnish response header"
				# Has both the ID of the current request and the ID of the request that populated the cache.
				it "Has 2 request IDs."
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

				describe "Request with 3rd party Cookie"
					it "Has a cache hit."
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
				end

				describe "Request with PHP session Cookie"
					phpsessid="$(
						expect test/telnet-proxy-tcp4.exp \
							127.0.0.2 \
							127.0.0.1 \
							${container_port_8443} \
							'HEAD /session.php HTTP/1.1' \
							| sed -En '/^HTTP\/[0-9\.]+ [0-9]+/,$p' \
							| sed '/Connection closed by foreign host./d' \
							| grep -Eo 'PHPSESSID=[^;]+' \
							| sed 's~PHPSESSID=~~'
					)"

					printf -v \
						request_headers \
						-- 'Host: %s\n%s\n%s' \
						"${backend_hostname}" \
						"Cookie: key_1=data_1; PHPSESSID=${phpsessid}" \
						"Connection: close"

					it "Has a cache pass."
						header_x_varnish="$(
							expect test/telnet-proxy-tcp4.exp \
								127.0.0.2 \
								127.0.0.1 \
								${container_port_8443} \
								'HEAD /session.php HTTP/1.1' "${request_headers}" \
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
				end
			end

			it "Unsets the Via header."
				header_via="$(
					curl -sI \
						-H "Host: ${backend_hostname}" \
						http://127.0.0.1:${container_port_80}/ \
					| grep '^Via: ' \
					| tr -d '\r'
				)"

				assert equal \
					"${header_via}" \
					""
			end

			describe "Backend HTML content"
				it "Is unaltered."
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
		end

		describe "Backend offline"
			describe "HTTP request"
				it "Has a cache hit."
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
				end
			end

			describe "PROXY protocol request"
				it "Has a cache hit."
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
		end

		__terminate_container \
			varnish.1 \
		&> /dev/null
	end

	trap - \
		INT TERM EXIT
}

function test_custom_configuration ()
{
	local -r backend_hostname="localhost.localdomain"
	local -r backend_network="bridge_t1"
	local container_port_80=""
	local counter=0
	local varnish_logs=""
	local varnish_parameters=""
	local varnish_vcl_loaded_hash=""
	local varnish_vcl_source_hash=""

	trap "__terminate_container varnish.1 &> /dev/null; \
		__destroy; \
		exit 1" \
		INT TERM EXIT

	describe "Customised Varnish configuration"
		describe "Runs named container"
			__terminate_container \
				varnish.1 \
			&> /dev/null

			it "Can publish ${DOCKER_PORT_MAP_TCP_80}:80."
				docker run \
					--detach \
					--name varnish.1 \
					--env "VARNISH_MAX_THREADS=5000" \
					--env "VARNISH_MIN_THREADS=100" \
					--env "VARNISH_THREAD_TIMEOUT=300" \
					--env "VARNISH_STORAGE=malloc,256M" \
					--env "VARNISH_TTL=600" \
					--env "VARNISH_VCL_CONF=dmNsIDQuMDsKCmltcG9ydCBkaXJlY3RvcnM7CmltcG9ydCBzdGQ7CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEhlYWx0aGNoZWNrIHByb2JlIChiYXNpYykKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KcHJvYmUgaGVhbHRoY2hlY2sgewoJLmludGVydmFsID0gNXM7CgkudGltZW91dCA9IDJzOwoJLndpbmRvdyA9IDU7CgkudGhyZXNob2xkID0gMzsKCS5pbml0aWFsID0gMjsKCS5leHBlY3RlZF9yZXNwb25zZSA9IDIwMDsKCS5yZXF1ZXN0ID0KCQkiR0VUIC8gSFRUUC8xLjEiCgkJIkhvc3Q6IGxvY2FsaG9zdC5sb2NhbGRvbWFpbiIKCQkiQ29ubmVjdGlvbjogY2xvc2UiCgkJIlVzZXItQWdlbnQ6IFZhcm5pc2giCgkJIkFjY2VwdC1FbmNvZGluZzogZ3ppcCwgZGVmbGF0ZSI7Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgSFRUUCBCYWNrZW5kcwojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQpiYWNrZW5kIGh0dHBfMSB7IC5ob3N0ID0gImh0dHBkXzEiOyAucG9ydCA9ICI4MCI7IC5maXJzdF9ieXRlX3RpbWVvdXQgPSAzMDBzOyAucHJvYmUgPSBoZWFsdGhjaGVjazsgfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBIVFRQIChIVFRQUyBUZXJtaW5hdGVkKSBCYWNrZW5kcwojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQpiYWNrZW5kIHByb3h5XzEgeyAuaG9zdCA9ICJodHRwZF8xIjsgLnBvcnQgPSAiODQ0MyI7IC5maXJzdF9ieXRlX3RpbWVvdXQgPSAzMDBzOyAucHJvYmUgPSBoZWFsdGhjaGVjazsgfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBEaXJlY3RvcnMKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0Kc3ViIHZjbF9pbml0IHsKCW5ldyBkaXJlY3Rvcl9odHRwID0gZGlyZWN0b3JzLnJvdW5kX3JvYmluKCk7CglkaXJlY3Rvcl9odHRwLmFkZF9iYWNrZW5kKGh0dHBfMSk7CgoJbmV3IGRpcmVjdG9yX3Byb3h5ID0gZGlyZWN0b3JzLnJvdW5kX3JvYmluKCk7CglkaXJlY3Rvcl9wcm94eS5hZGRfYmFja2VuZChwcm94eV8xKTsKfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBDbGllbnQgc2lkZQojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQpzdWIgdmNsX3JlY3YgewoJaWYgKHJlcS5tZXRob2QgPT0gIlBSSSIpIHsKCQkjIFJlamVjdCBTUERZIG9yIEhUVFAvMi4wIHdpdGggTWV0aG9kIE5vdCBBbGxvd2VkCgkJcmV0dXJuIChzeW50aCg0MDUpKTsKCX0KCgl1bnNldCByZXEuaHR0cC5Gb3J3YXJkZWQ7Cgl1bnNldCByZXEuaHR0cC5YLUZvcndhcmRlZC1Qb3J0OwoJdW5zZXQgcmVxLmh0dHAuWC1Gb3J3YXJkZWQtUHJvdG87CgoJaWYgKHN0ZC5wb3J0KHNlcnZlci5pcCkgPT0gODQ0MyB8fAoJCXN0ZC5wb3J0KGxvY2FsLmlwKSA9PSA4NDQzKSB7CgkJIyBTU0wgVGVybWluYXRlZCB1cHN0cmVhbSBzbyBpbmRjYXRlIHRoaXMgd2l0aCBhIGN1c3RvbSBoZWFkZXIKCQlzZXQgcmVxLmh0dHAuWC1Gb3J3YXJkZWQtUG9ydCA9ICI0NDMiOwoJCXNldCByZXEuaHR0cC5YLUZvcndhcmRlZC1Qcm90byA9ICJodHRwcyI7CgkJc2V0IHJlcS5iYWNrZW5kX2hpbnQgPSBkaXJlY3Rvcl9wcm94eS5iYWNrZW5kKCk7Cgl9IGVsc2UgaWYgKHN0ZC5wb3J0KHNlcnZlci5pcCkgPT0gODAgfHwKCQlzdGQucG9ydChsb2NhbC5pcCkgPT0gODApIHsKCQkjIERlZmF1bHQgdG8gSFRUUAoJCXNldCByZXEuaHR0cC5YLUZvcndhcmRlZC1Qb3J0ID0gIjgwIjsKCQlzZXQgcmVxLmJhY2tlbmRfaGludCA9IGRpcmVjdG9yX2h0dHAuYmFja2VuZCgpOwoJfSBlbHNlIHsKCQlyZXR1cm4gKHN5bnRoKDQwMykpOwoJfQoKCSMgc2V0IHJlcS5odHRwLlgtVmFybmlzaC1HcmFjZSA9ICJub25lIjsKCglpZiAocmVxLm1ldGhvZCAhPSAiR0VUIiAmJgoJCXJlcS5tZXRob2QgIT0gIkhFQUQiICYmCgkJcmVxLm1ldGhvZCAhPSAiUFVUIiAmJgoJCXJlcS5tZXRob2QgIT0gIlBPU1QiICYmCgkJcmVxLm1ldGhvZCAhPSAiVFJBQ0UiICYmCgkJcmVxLm1ldGhvZCAhPSAiT1BUSU9OUyIgJiYKCQlyZXEubWV0aG9kICE9ICJERUxFVEUiKSB7CgkJIyBOb24tUkZDMjYxNiBvciBDT05ORUNUIHdoaWNoIGlzIHdlaXJkLgoJCXJldHVybiAocGlwZSk7Cgl9CgoJaWYgKHJlcS5tZXRob2QgIT0gIkdFVCIgJiYKCQlyZXEubWV0aG9kICE9ICJIRUFEIikgewoJCSMgT25seSBkZWFsIHdpdGggR0VUIGFuZCBIRUFEIGJ5IGRlZmF1bHQKCQlyZXR1cm4gKHBhc3MpOwoJfQoKCSMgSGFuZGxlIEV4cGVjdCByZXF1ZXN0CglpZiAocmVxLmh0dHAuRXhwZWN0KSB7CgkJcmV0dXJuIChwaXBlKTsKCX0KCgkjIENhY2hlLUNvbnRyb2wKCWlmIChyZXEuaHR0cC5DYWNoZS1Db250cm9sIH4gIihwcml2YXRlfG5vLWNhY2hlfG5vLXN0b3JlKSIpIHsKCQlyZXR1cm4gKHBhc3MpOwoJfQoKCXNldCByZXEuaHR0cC5YLUNvb2tpZSA9IHJlcS5odHRwLkNvb2tpZTsKCXVuc2V0IHJlcS5odHRwLkNvb2tpZTsKfQoKc3ViIHZjbF9oYXNoIHsKCWhhc2hfZGF0YShyZXEudXJsKTsKCglpZiAocmVxLmh0dHAuaG9zdCkgewoJCWhhc2hfZGF0YShyZXEuaHR0cC5ob3N0KTsKCX0gZWxzZSB7CgkJaGFzaF9kYXRhKHNlcnZlci5pcCk7Cgl9CgoJaWYgKHJlcS5odHRwLlgtRm9yd2FyZGVkLVByb3RvKSB7CgkJaGFzaF9kYXRhKHJlcS5odHRwLlgtRm9yd2FyZGVkLVByb3RvKTsKCX0KCglpZiAocmVxLmh0dHAuWC1Db29raWUpIHsKCQlzZXQgcmVxLmh0dHAuQ29va2llID0gcmVxLmh0dHAuWC1Db29raWU7CgkJdW5zZXQgcmVxLmh0dHAuWC1Db29raWU7Cgl9CgoJcmV0dXJuIChsb29rdXApOwp9CgpzdWIgdmNsX2hpdCB7CglpZiAob2JqLnR0bCA+PSAwcykgewoJCXJldHVybiAoZGVsaXZlcik7Cgl9CgoJaWYgKHN0ZC5oZWFsdGh5KHJlcS5iYWNrZW5kX2hpbnQpICYmCgkJb2JqLnR0bCArIDE1cyA+IDBzKSB7CgkJIyBzZXQgcmVxLmh0dHAuWC1WYXJuaXNoLUdyYWNlID0gIm5vcm1hbCI7CgkJcmV0dXJuIChkZWxpdmVyKTsKCX0gZWxzZSBpZiAob2JqLnR0bCArIG9iai5ncmFjZSA+IDBzKSB7CgkJIyBzZXQgcmVxLmh0dHAuWC1WYXJuaXNoLUdyYWNlID0gImZ1bGwiOwoJCXJldHVybiAoZGVsaXZlcik7Cgl9CgoJcmV0dXJuIChtaXNzKTsKfQoKc3ViIHZjbF9kZWxpdmVyIHsKCSMgc2V0IHJlc3AuaHR0cC5YLVZhcm5pc2gtR3JhY2UgPSByZXEuaHR0cC5YLVZhcm5pc2gtR3JhY2U7CgoJcmV0dXJuIChkZWxpdmVyKTsKfQoKIyBFcnJvcnM6IDQxMywgNDE3ICYgNTAzCnN1YiB2Y2xfc3ludGggewoJc2V0IHJlc3AuaHR0cC5Db250ZW50LVR5cGUgPSAidGV4dC9odG1sOyBjaGFyc2V0PXV0Zi04IjsKCXNldCByZXNwLmh0dHAuUmV0cnktQWZ0ZXIgPSAiNSI7CglzeW50aGV0aWMoIHsiPCFET0NUWVBFIGh0bWw+CjxodG1sPgoJPGhlYWQ+CgkJPHRpdGxlPkVycm9yPC90aXRsZT4KCQk8c3R5bGU+CgkJCWJvZHl7Zm9udC1mYW1pbHk6c2Fucy1zZXJpZjtjb2xvcjojNjY2O2JhY2tncm91bmQtY29sb3I6I2YxZjFmMTttYXJnaW46MTIlO21heC13aWR0aDo1MCU7fQoJCQloMXtjb2xvcjojMzMzO2ZvbnQtc2l6ZToxLjVlbTtmb250LXdlaWdodDo0MDA7dGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlO30KCQk8L3N0eWxlPgoJPC9oZWFkPgoJPGJvZHk+CgkJPGgxPiJ9ICsgcmVzcC5zdGF0dXMgKyAiICIgKyByZXNwLnJlYXNvbiArIHsiPC9oMT4KCQk8cD4ifSArIHJlc3AucmVhc29uICsgeyI8L3A+CgkJPHA+WElEOiAifSArIHJlcS54aWQgKyB7IjwvcD4KCTwvYm9keT4KPC9odG1sPgoifSApOwoJcmV0dXJuIChkZWxpdmVyKTsKfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBCYWNrZW5kCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCnN1YiB2Y2xfYmFja2VuZF9yZXNwb25zZSB7CgkjIEtlZXAgb2JqZWN0cyBiZXlvbmQgdGhlaXIgdHRsCglzZXQgYmVyZXNwLmdyYWNlID0gNmg7CgoJaWYgKGJlcmVzcC50dGwgPD0gMHMgfHwKCQliZXJlc3AuaHR0cC5TZXQtQ29va2llIHx8CgkJYmVyZXNwLmh0dHAuU3Vycm9nYXRlLWNvbnRyb2wgfiAibm8tc3RvcmUiIHx8CgkJKCAhIGJlcmVzcC5odHRwLlN1cnJvZ2F0ZS1Db250cm9sICYmCgkJCWJlcmVzcC5odHRwLkNhY2hlLUNvbnRyb2wgfiAiKHByaXZhdGV8bm8tY2FjaGV8bm8tc3RvcmUpIikgfHwKCQliZXJlc3AuaHR0cC5WYXJ5ID09ICIqIikgewoJCSMgTWFyayBhcyAiSGl0LUZvci1QYXNzIiBmb3IgdGhlIG5leHQgMiBtaW51dGVzCgkJc2V0IGJlcmVzcC51bmNhY2hlYWJsZSA9IHRydWU7CgkJc2V0IGJlcmVzcC50dGwgPSAxMjBzOwoJCXJldHVybiAoZGVsaXZlcik7Cgl9CgoJcmV0dXJuIChkZWxpdmVyKTsKfQoKc3ViIHZjbF9iYWNrZW5kX2Vycm9yIHsKCXNldCBiZXJlc3AuaHR0cC5Db250ZW50LVR5cGUgPSAidGV4dC9odG1sOyBjaGFyc2V0PXV0Zi04IjsKCXNldCBiZXJlc3AuaHR0cC5SZXRyeS1BZnRlciA9ICI1IjsKCXN5bnRoZXRpYyggeyI8IURPQ1RZUEUgaHRtbD4KPGh0bWw+Cgk8c3R5bGU+CgkJYm9keXtmb250LWZhbWlseTpzYW5zLXNlcmlmO2NvbG9yOiM2NjY7YmFja2dyb3VuZC1jb2xvcjojZjFmMWYxO21hcmdpbjoxMiU7bWF4LXdpZHRoOjUwJTt9CgkJaDF7Y29sb3I6IzMzMztmb250LXNpemU6MS41ZW07Zm9udC13ZWlnaHQ6NDAwO3RleHQtdHJhbnNmb3JtOnVwcGVyY2FzZTt9Cgk8L3N0eWxlPgoJPGhlYWQ+CgkJPHRpdGxlPkVycm9yPC90aXRsZT4KCTwvaGVhZD4KCTxib2R5PgoJCTxoMT4ifSArIGJlcmVzcC5zdGF0dXMgKyAiICIgKyBiZXJlc3AucmVhc29uICsgeyI8L2gxPgoJCTxwPiJ9ICsgYmVyZXNwLnJlYXNvbiArIHsiPC9wPgoJCTxwPlhJRDogIn0gKyBiZXJlcS54aWQgKyB7IjwvcD4KCTwvYm9keT4KPC9odG1sPgoifSApOwoJcmV0dXJuIChkZWxpdmVyKTsKfQo=" \
					--network ${backend_network} \
					--publish ${DOCKER_PORT_MAP_TCP_80}:80 \
					--publish ${DOCKER_PORT_MAP_TCP_8443}:8443 \
					--ulimit memlock=82000 \
					--ulimit nofile=131072 \
					--ulimit nproc=65535 \
					jdeathe/centos-ssh-varnish:latest \
				&> /dev/null

				container_port_80="$(
					__get_container_port \
						varnish.1 \
						80/tcp
				)"

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
		end

		if ! __is_container_ready \
			varnish.1 \
			${STARTUP_TIME} \
			"/usr/sbin/varnishd " \
			"varnishadm vcl.show -v boot"
		then
			exit 1
		fi

		describe "Custom initialisation"
			varnish_logs="$(
				docker logs \
					varnish.1 \
				2>&1
			)"

			varnish_parameters="$(
				docker exec -t \
					varnish.1 \
					varnishadm param.show
			)"

			# Runs varnishd with a maximum of 5000 worker threads in each pool.
			it "Sets thread_pool_max=5000."
				assert __shpec_matcher_egrep \
					"${varnish_parameters}" \
					"^thread_pool_max[ ]+5000[^0-9]+"
			end

			# Runs varnishd with a minimum of 100 worker threads in each pool.
			it "Sets thread_pool_min=100."
				assert __shpec_matcher_egrep \
					"${varnish_parameters}" \
					"^thread_pool_min[ ]+100[^0-9]+"
			end

			# Will destroy threads in excess of 100, which have been idle for at least 300 seconds.
			it "Sets thread_pool_timeout=300."
				assert __shpec_matcher_egrep \
					"${varnish_parameters}" \
					"^thread_pool_timeout[ ]+300[^0-9]+"
			end

			# Sets a 600 second default TTL when not assigned by a backend or VCL.
			it "Sets default_ttl=600."
				assert __shpec_matcher_egrep \
					"${varnish_parameters}" \
					"^default_ttl[ ]+600[^0-9]+"
			end

			# Sets the default storage backend to memory based with a size of 256M.
			it "Sets a 256M malloc storage."
				assert __shpec_matcher_egrep \
					"${varnish_logs}" \
					"^storage : malloc,256M"
			end

			describe "VCL file"
				it "Sets path to docker-default.vcl."
					assert __shpec_matcher_egrep \
						"${varnish_logs}" \
						"^vcl : \/etc\/varnish\/docker-default\.vcl"
				end

				it "Is unaltered."
					varnish_vcl_loaded_hash="$(
						docker exec \
							varnish.1 \
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
		end

		__terminate_container \
			varnish.1 \
		&> /dev/null
	end

	describe "Configure autostart"
		__terminate_container \
			varnish.1 \
		&> /dev/null

		it "Can disable varnishd-wrapper."
			docker run \
				--detach \
				--name varnish.1 \
				--env VARNISH_AUTOSTART_VARNISHD_WRAPPER=false \
				--network ${backend_network} \
				--publish ${DOCKER_PORT_MAP_TCP_80}:80 \
				--publish ${DOCKER_PORT_MAP_TCP_8443}:8443 \
				jdeathe/centos-ssh-varnish:latest \
			&> /dev/null

			sleep ${STARTUP_TIME}

			docker ps \
				--filter "name=varnish.1" \
				--filter "health=healthy" \
			&> /dev/null \
			&& docker top \
				varnish.1 \
			| grep -qE '/usr/sbin/varnishd '

			assert equal \
				"${?}" \
				"1"
		end

		__terminate_container \
			varnish.1 \
		&> /dev/null

		it "Can enable varnishncsa-wrapper."
			docker run \
				--detach \
				--name varnish.1 \
				--env VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER=true \
				--network ${backend_network} \
				--publish ${DOCKER_PORT_MAP_TCP_80}:80 \
				--publish ${DOCKER_PORT_MAP_TCP_8443}:8443 \
				jdeathe/centos-ssh-varnish:latest \
			&> /dev/null

			if ! __is_container_ready \
				varnish.1 \
				${STARTUP_TIME} \
				"/usr/sbin/varnishd " \
				"varnishadm vcl.show -v boot"
			then
				exit 1
			fi

			docker ps \
				--filter "name=varnish.1" \
				--filter "health=healthy" \
			&> /dev/null \
			&& docker top \
				varnish.1 \
			| grep -qE '/usr/bin/varnishncsa '

			assert equal \
				"${?}" \
				"0"
		end

		__terminate_container \
			varnish.1 \
		&> /dev/null
	end

	describe "Configure Apache/NCSA access log"
		__terminate_container \
			varnish.1 \
		&> /dev/null

		it "Outputs in combined format."
			docker run \
				--detach \
				--name varnish.1 \
				--env VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER=true \
				--network ${backend_network} \
				--publish ${DOCKER_PORT_MAP_TCP_80}:80 \
				--publish ${DOCKER_PORT_MAP_TCP_8443}:8443 \
				jdeathe/centos-ssh-varnish:latest \
			&> /dev/null

			if ! __is_container_ready \
				varnish.1 \
				${STARTUP_TIME} \
				"/usr/sbin/varnishd " \
				"varnishadm vcl.show -v boot"
			then
				exit 1
			fi

			if ! __is_container_ready \
				varnish.1 \
				${STARTUP_TIME} \
				"/usr/bin/varnishncsa "
			then
				exit 1
			fi

			container_port_80="$(
				__get_container_port \
					varnish.1 \
					80/tcp
			)"

			# Make a request to populate the access_log
			curl -sI \
				-X GET \
				-H "Host: ${backend_hostname}" \
				http://127.0.0.1:${container_port_80}/ \
			&> /dev/null

			sleep 2

			docker logs \
				--tail 1 \
				varnish.1 \
			| grep -qE \
				"^.+ .+ .+ \[.+\] \"GET (http:\/\/${backend_hostname})?/ HTTP/1\.1\" 200 .+ \".+\" \".*\"\$" \
			&> /dev/null

			assert equal \
				"${?}" \
				0
		end

		__terminate_container \
			varnish.1 \
		&> /dev/null

		it "Outputs in custom format."
			docker run \
				--detach \
				--name varnish.1 \
				--env VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER=true \
				--env VARNISH_VARNISHNCSA_FORMAT="%h %l %u %t \"%r\" %s %b \"%{Referer}i\" \"%{User-agent}i\" %{Varnish:hitmiss}x" \
				--network ${backend_network} \
				--publish ${DOCKER_PORT_MAP_TCP_80}:80 \
				--publish ${DOCKER_PORT_MAP_TCP_8443}:8443 \
				jdeathe/centos-ssh-varnish:latest \
			&> /dev/null

			if ! __is_container_ready \
				varnish.1 \
				${STARTUP_TIME} \
				"/usr/sbin/varnishd " \
				"varnishadm vcl.show -v boot"
			then
				exit 1
			fi

			if ! __is_container_ready \
				varnish.1 \
				${STARTUP_TIME} \
				"/usr/bin/varnishncsa "
			then
				exit 1
			fi

			container_port_80="$(
				__get_container_port \
					varnish.1 \
					80/tcp
			)"

			# Make a request to populate the access_log
			curl -sI \
				-X GET \
				-H "Host: ${backend_hostname}" \
				http://127.0.0.1:${container_port_80}/ \
			&> /dev/null

			sleep 2

			docker logs \
				--tail 1 \
				varnish.1 \
			| grep -qE \
				"^.+ .+ .+ \[.+\] \"GET (http:\/\/${backend_hostname})?/ HTTP/1\.1\" 200 .+ \".+\" \".*\" (hit|miss)+\$" \
			&> /dev/null

			assert equal \
				"${?}" \
				0
		end

		__terminate_container \
			varnish.1 \
		&> /dev/null
	end

	trap - \
		INT TERM EXIT
}

function test_healthcheck ()
{
	local -r backend_network="bridge_t1"
	local -r event_lag_seconds=2
	local -r interval_seconds=1
	local -r retries=2
	local container_id
	local events_since_timestamp
	local health_status

	describe "Healthcheck"
		trap "__terminate_container varnish.1 &> /dev/null; \
			__destroy; \
			exit 1" \
			INT TERM EXIT

		describe "Default configuration"
			__terminate_container \
				varnish.1 \
			&> /dev/null

			docker run \
				--detach \
				--name varnish.1 \
				--network ${backend_network} \
				jdeathe/centos-ssh-varnish:latest \
			&> /dev/null

			events_since_timestamp="$(
				date +%s
			)"

			container_id="$(
				docker ps \
					--quiet \
					--filter "name=varnish.1"
			)"

			it "Returns a valid status on starting."
				health_status="$(
					docker inspect \
						--format='{{json .State.Health.Status}}' \
						varnish.1
				)"

				assert __shpec_matcher_egrep \
					"${health_status}" \
					"\"(starting|healthy|unhealthy)\""
			end

			it "Returns healthy after startup."
				events_timeout="$(
					awk \
						-v event_lag="${event_lag_seconds}" \
						-v interval="${interval_seconds}" \
						-v startup_time="${STARTUP_TIME}" \
						'BEGIN { print event_lag + startup_time + interval; }'
				)"

				health_status="$(
					test/health_status \
						--container="${container_id}" \
						--since="${events_since_timestamp}" \
						--timeout="${events_timeout}" \
						--monochrome \
					2>&1
				)"

				assert equal \
					"${health_status}" \
					"✓ healthy"
			end

			it "Returns unhealthy on failure."
				docker exec -t \
					varnish.1 \
					bash -c "mv \
						/usr/sbin/varnishd \
						/usr/sbin/varnishd2" \
				&& docker exec -t \
					varnish.1 \
					bash -c "if [[ -n \$(pgrep -f '^/usr/sbin/varnishd ') ]]; then \
						kill -9 \$(pgrep -f '^/usr/sbin/varnishd ')
					fi"

				events_since_timestamp="$(
					date +%s
				)"

				events_timeout="$(
					awk \
						-v event_lag="${event_lag_seconds}" \
						-v interval="${interval_seconds}" \
						-v retries="${retries}" \
						'BEGIN { print (2 * event_lag) + (interval * retries); }'
				)"

				health_status="$(
					test/health_status \
						--container="${container_id}" \
						--since="$(( ${event_lag_seconds} + ${events_since_timestamp} ))" \
						--timeout="${events_timeout}" \
						--monochrome \
					2>&1
				)"

				assert equal \
					"${health_status}" \
					"✗ unhealthy"
			end
		end

		describe "Enable varnishncsa-wrapper"
			__terminate_container \
				varnish.1 \
			&> /dev/null

			docker run \
				--detach \
				--name varnish.1 \
				--env VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER=true \
				--network ${backend_network} \
				jdeathe/centos-ssh-varnish:latest \
			&> /dev/null

			events_since_timestamp="$(
				date +%s
			)"

			container_id="$(
				docker ps \
					--quiet \
					--filter "name=varnish.1"
			)"

			it "Returns a valid status on starting."
				health_status="$(
					docker inspect \
						--format='{{json .State.Health.Status}}' \
						varnish.1
				)"

				assert __shpec_matcher_egrep \
					"${health_status}" \
					"\"(starting|healthy|unhealthy)\""
			end

			it "Returns healthy after startup."
				events_timeout="$(
					awk \
						-v event_lag="${event_lag_seconds}" \
						-v interval="${interval_seconds}" \
						-v startup_time="${STARTUP_TIME}" \
						'BEGIN { print event_lag + startup_time + interval; }'
				)"

				health_status="$(
					test/health_status \
						--container="${container_id}" \
						--since="${events_since_timestamp}" \
						--timeout="${events_timeout}" \
						--monochrome \
					2>&1
				)"

				assert equal \
					"${health_status}" \
					"✓ healthy"
			end
		end

		describe "Disable all"
			__terminate_container \
				varnish.1 \
			&> /dev/null

			docker run \
				--detach \
				--name varnish.1 \
				--env VARNISH_AUTOSTART_VARNISHD_WRAPPER=false \
				--env VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER=false \
				--network ${backend_network} \
				jdeathe/centos-ssh-varnish:latest \
			&> /dev/null

			events_since_timestamp="$(
				date +%s
			)"

			container_id="$(
				docker ps \
					--quiet \
					--filter "name=varnish.1"
			)"

			it "Returns a valid status on starting."
				health_status="$(
					docker inspect \
						--format='{{json .State.Health.Status}}' \
						varnish.1
				)"

				assert __shpec_matcher_egrep \
					"${health_status}" \
					"\"(starting|healthy|unhealthy)\""
			end

			it "Returns healthy after startup."
				events_timeout="$(
					awk \
						-v event_lag="${event_lag_seconds}" \
						-v interval="${interval_seconds}" \
						-v startup_time="${STARTUP_TIME}" \
						'BEGIN { print event_lag + startup_time + interval; }'
				)"

				health_status="$(
					test/health_status \
						--container="${container_id}" \
						--since="${events_since_timestamp}" \
						--timeout="${events_timeout}" \
						--monochrome \
					2>&1
				)"

				assert equal \
					"${health_status}" \
					"✓ healthy"
			end
		end

		__terminate_container \
			varnish.1 \
		&> /dev/null

		trap - \
			INT TERM EXIT
	end
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
	test_healthcheck
	__destroy
end
