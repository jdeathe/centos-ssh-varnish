#!/usr/bin/env bash

DIR_PATH="$( if [ "$( echo "${0%/*}" )" != "$( echo "${0}" )" ] ; then cd "$( echo "${0%/*}" )"; fi; pwd )"
if [[ $DIR_PATH == */* ]] && [[ $DIR_PATH != "$( pwd )" ]] ; then
	cd $DIR_PATH
fi

source run.conf

OPTS_BACKEND_HOST_1="${BACKEND_HOST_1:-172.17.8.101}"
OPTS_BACKEND_HOST_2="${BACKEND_HOST_2:-172.17.8.102}"
OPTS_BACKEND_HOST_3="${BACKEND_HOST_3:-172.17.8.103}"
OPTS_BACKEND_HOST_4="${BACKEND_HOST_4:-172.17.8.104}"
OPTS_BACKEND_HOST_5="${BACKEND_HOST_5:-172.17.8.105}"
OPTS_BACKEND_HOST_6="${BACKEND_HOST_6:-172.17.8.106}"
OPTS_BACKEND_HOST_7="${BACKEND_HOST_7:-172.17.8.107}"
OPTS_BACKEND_HOST_8="${BACKEND_HOST_8:-172.17.8.108}"
OPTS_BACKEND_HOST_9="${BACKEND_HOST_9:-172.17.8.109}"

have_docker_container_name ()
{
	local NAME=$1

	if [[ -n $(docker ps -a | grep -v -e "${NAME}/.*,.*" | grep -o ${NAME}) ]]; then
		return 0
	else
		return 1
	fi
}

is_docker_container_name_running ()
{
	local NAME=$1

	if [[ -n $(docker ps | grep -v -e "${NAME}/.*,.*" | grep -o ${NAME}) ]]; then
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

# Force replace container of same name if found to exist
remove_docker_container_name ${DOCKER_NAME}

# In a sub-shell set xtrace - prints the docker command to screen for reference
(
set -x
sudo docker run \
	-d \
	--privileged \
	--name ${DOCKER_NAME} \
	-p 8000:80 \
	-p 8500:8443 \
	--add-host backend-1:${OPTS_BACKEND_HOST_1} \
	--add-host backend-2:${OPTS_BACKEND_HOST_2} \
	--add-host backend-3:${OPTS_BACKEND_HOST_3} \
	--add-host backend-4:${OPTS_BACKEND_HOST_4} \
	${DOCKER_IMAGE_REPOSITORY_NAME}
)

# Example: Override the storage settings to use memory instead of disk based cache
# (
# set -x
# sudo docker run \
# 	-d \
#   --privileged \
# 	--name ${DOCKER_NAME} \
# 	-p 8000:80 \
# 	-p 8500:8443 \
# 	--env VARNISH_STORAGE=malloc,256M \
# 	${DOCKER_IMAGE_REPOSITORY_NAME}
# )

if is_docker_container_name_running ${DOCKER_NAME} ; then
	docker ps | grep -v -e "${DOCKER_NAME}/.*,.*" | grep ${DOCKER_NAME}
	echo " ---> Docker container running."
fi
