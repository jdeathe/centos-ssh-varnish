
# Handle incrementing the docker host port for instances unless a port range is defined.
DOCKER_PUBLISH=
if [[ ${DOCKER_PORT_MAP_TCP_80} != NULL ]]; then
	if grep -qE '^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:)?[0-9]*$' <<< "${DOCKER_PORT_MAP_TCP_80}" \
		&& grep -qE '^.+\.([0-9]+)\.([0-9]+)$' <<< "${DOCKER_NAME}"; then
		printf -v \
			DOCKER_PUBLISH \
			-- '%s --publish %s%s:80' \
			"${DOCKER_PUBLISH}" \
			"$(grep -o '^[0-9\.]*:' <<< "${DOCKER_PORT_MAP_TCP_80}")" \
			"$(( $(grep -o '[0-9]*$' <<< "${DOCKER_PORT_MAP_TCP_80}") + $(sed 's~\.[0-9]*$~~' <<< "${DOCKER_NAME}" | awk -F. '{ print $NF; }') - 1 ))"
	else
		printf -v \
			DOCKER_PUBLISH \
			-- '%s --publish %s:80' \
			"${DOCKER_PUBLISH}" \
			"${DOCKER_PORT_MAP_TCP_80}"
	fi
fi

if [[ ${DOCKER_PORT_MAP_TCP_8443} != NULL ]]; then
	if grep -qE '^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:)?[0-9]*$' <<< "${DOCKER_PORT_MAP_TCP_8443}" \
		&& grep -qE '^.+\.([0-9]+)\.([0-9]+)$' <<< "${DOCKER_NAME}"; then
		printf -v \
			DOCKER_PUBLISH \
			-- '%s --publish %s%s:8443' \
			"${DOCKER_PUBLISH}" \
			"$(grep -o '^[0-9\.]*:' <<< "${DOCKER_PORT_MAP_TCP_8443}")" \
			"$(( $(grep -o '[0-9]*$' <<< "${DOCKER_PORT_MAP_TCP_8443}") + $(sed 's~\.[0-9]*$~~' <<< "${DOCKER_NAME}" | awk -F. '{ print $NF; }') - 1 ))"
	else
		printf -v \
			DOCKER_PUBLISH \
			-- '%s --publish %s:8443' \
			"${DOCKER_PUBLISH}" \
			"${DOCKER_PORT_MAP_TCP_8443}"
	fi
fi

# Common parameters of create and run targets
DOCKER_CONTAINER_PARAMETERS="-t \
--name ${DOCKER_NAME} \
--restart ${DOCKER_RESTART_POLICY} \
--ulimit memlock=${ULIMIT_MEMLOCK} \
--ulimit nofile=${ULIMIT_NOFILE} \
--ulimit nproc=${ULIMIT_NPROC} \
--env \"VARNISH_ADMIN_LISTEN_ADDRESS=${VARNISH_ADMIN_LISTEN_ADDRESS}\" \
--env \"VARNISH_ADMIN_LISTEN_PORT=${VARNISH_ADMIN_LISTEN_PORT}\" \
--env \"VARNISH_LISTEN_ADDRESS=${VARNISH_LISTEN_ADDRESS}\" \
--env \"VARNISH_LISTEN_PORT=${VARNISH_LISTEN_PORT}\" \
--env \"VARNISH_MAX_THREADS=${VARNISH_MAX_THREADS}\" \
--env \"VARNISH_MIN_THREADS=${VARNISH_MIN_THREADS}\" \
--env \"VARNISH_PIDFILE=${VARNISH_PIDFILE}\" \
--env \"VARNISH_SECRET_FILE=${VARNISH_SECRET_FILE}\" \
--env \"VARNISH_STORAGE=${VARNISH_STORAGE}\" \
--env \"VARNISH_THREAD_TIMEOUT=${VARNISH_THREAD_TIMEOUT}\" \
--env \"VARNISH_TTL=${VARNISH_TTL}\" \
--env \"VARNISH_VCL_CONF=${VARNISH_VCL_CONF}\" \
${DOCKER_PUBLISH}"
