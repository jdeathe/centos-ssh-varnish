#!/usr/bin/env bash

DIR_PATH="$( if [ "$( echo "${0%/*}" )" != "$( echo "${0}" )" ] ; then cd "$( echo "${0%/*}" )"; fi; pwd )"
if [[ $DIR_PATH == */* ]] && [[ $DIR_PATH != "$( pwd )" ]] ; then
	cd $DIR_PATH
fi

source run.conf

have_docker_container_name ()
{
	local NAME=$1

	if [[ -n $(docker ps -a | awk -v pattern="^${NAME}$" '$NF ~ pattern { print $NF; }') ]]; then
		return 0
	else
		return 1
	fi
}

is_docker_container_name_running ()
{
	local NAME=$1

	if [[ -n $(docker ps | awk -v pattern="^${NAME}$" '$NF ~ pattern { print $NF; }') ]]; then
		return 0
	else
		return 1
	fi
}

remove_docker_container_name ()
{
	local NAME=$1

	if have_docker_container_name ${NAME} ; then
		if is_docker_container_name_running ${NAME} ; then
			echo Stopping container ${NAME}...
			(docker stop ${NAME})
		fi
		echo Removing container ${NAME}...
		(docker rm ${NAME})
	fi
}

# Set the --add-host parameters
DOCKER_HOST_TYPE=${DOCKER_HOST_TYPE:-default}
ADD_BACKEND_HOSTS=

case ${DOCKER_HOST_TYPE} in
	cluster)
		if [[ ${VARNISH_VCL_CONF} == /etc/varnish/docker-cluster.vcl ]]; then
			echo Running Varnish with 3 backend cluster nodes.
			ADD_BACKEND_HOSTS="--add-host backend-1:${DOCKER_HOST_IP_CLUSTER_01} \
								--add-host backend-2:${DOCKER_HOST_IP_CLUSTER_02} \
								--add-host backend-3:${DOCKER_HOST_IP_CLUSTER_03}"
		else
			echo Running Varnish with 1 backend cluster node.
			ADD_BACKEND_HOSTS="--add-host backend-1:${DOCKER_HOST_IP_CLUSTER_01}"
		fi
		;;
	*)
		echo Running Varnish with 1 backend node.

		# Fail if attempting to use the wrong Varnish VCL configuration.
		if [[ ${VARNISH_VCL_CONF} == /etc/varnish/docker-cluster.vcl ]]; then
			echo ERROR: Varnish configuration docker-cluster.vcl requires DOCKER_HOST_TYPE=cluster
			exit 1
		fi

		DOCKER_HOST_IP=
		if [[ ${DOCKER_HOST} != "" ]]; then
			DOCKER_HOST_IP=$(echo ${DOCKER_HOST} | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
		fi

		if [[ ${DOCKER_HOST_IP} != "" ]] && [[ ${DOCKER_HOST_IP} != ${DOCKER_HOST_IP_DEFAULT} ]]; then
			echo Found non-standard DOCKER_HOST defined.
			echo Using ${DOCKER_HOST_IP} instead of ${DOCKER_HOST_IP_DEFAULT} for backend-1.
			ADD_BACKEND_HOSTS="--add-host backend-1:${DOCKER_HOST_IP}"
		else
			ADD_BACKEND_HOSTS="--add-host backend-1:${DOCKER_HOST_IP_DEFAULT}"
		fi
		;;
esac

# Configuration volume
if ! have_docker_container_name ${VOLUME_CONFIG_NAME} ; then

	# For configuration that is specific to the running container
	CONTAINER_MOUNT_PATH_CONFIG=${MOUNT_PATH_CONFIG}/${DOCKER_NAME}

	# For configuration that is shared across a group of containers
	CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH=${MOUNT_PATH_CONFIG}/ssh.${SERVICE_UNIT_SHARED_GROUP}

	if [ ! -d ${CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH}/ssh ]; then
		CMD=$(mkdir -p ${CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH}/ssh)
		$CMD || sudo $CMD
	fi

	# Configuration for SSH is from jdeathe/centos-ssh/etc/services-config/ssh
	#if [[ ! -n $(find ${CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH}/ssh -maxdepth 1 -type f) ]]; then
	#		CMD=$(cp -R etc/services-config/ssh/ ${CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH}/ssh/)
	#		$CMD || sudo $CMD
	#fi

	if [ ! -d ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor ]; then
		CMD=$(mkdir -p ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor)
		$CMD || sudo $CMD
	fi

	if [[ ! -n $(find ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor -maxdepth 1 -type f) ]]; then
		CMD=$(cp -R etc/services-config/supervisor ${CONTAINER_MOUNT_PATH_CONFIG}/)
		$CMD || sudo $CMD
	fi

	if [ ! -d ${CONTAINER_MOUNT_PATH_CONFIG}/varnish ]; then
		CMD=$(mkdir -p ${CONTAINER_MOUNT_PATH_CONFIG}/varnish)
		$CMD || sudo $CMD
	fi

	if [[ ! -n $(find ${CONTAINER_MOUNT_PATH_CONFIG}/varnish -maxdepth 1 -type f) ]]; then
		CMD=$(cp -R etc/services-config/varnish ${CONTAINER_MOUNT_PATH_CONFIG}/)
		$CMD || sudo $CMD
	fi
(
set -x
docker run \
	--name ${VOLUME_CONFIG_NAME} \
	-v ${CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH}/ssh:/etc/services-config/ssh \
	-v ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor:/etc/services-config/supervisor \
	-v ${CONTAINER_MOUNT_PATH_CONFIG}/varnish:/etc/services-config/varnish \
	busybox:latest \
	/bin/true;
)
fi

# Force replace container of same name if found to exist
remove_docker_container_name ${DOCKER_NAME}

# In a sub-shell set xtrace - prints the docker command to screen for reference
(
set -x
docker run \
	-d \
	--privileged \
	--name ${DOCKER_NAME} \
	-p 8000:80 \
	-p 8500:8443 \
	--env "VARNISH_VCL_CONF=${VARNISH_VCL_CONF}" \
	--env "VARNISH_STORAGE=${VARNISH_STORAGE}" \
	${ADD_BACKEND_HOSTS} \
	--volumes-from ${VOLUME_CONFIG_NAME} \
	${DOCKER_IMAGE_REPOSITORY_NAME}
)

if is_docker_container_name_running ${DOCKER_NAME} ; then
	docker ps | grep -v -e "${DOCKER_NAME}/.*,.*" | grep ${DOCKER_NAME}
	echo " ---> Docker container running."
fi
