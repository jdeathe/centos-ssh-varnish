centos-ssh-varnish
==================

Docker Image including CentOS-6 6.7 x86_64 and Varnish Cache 3.0.

Supports custom configuration via a configuration data volume.

## Overview & links

The [Dockerfile](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/Dockerfile) can be used to build a base image that can be run as-is or used as the bases for other more specific builds.

Included in the build is the EPEL repository and SSH, vi and MySQL are installed along with python-pip, supervisor and supervisor-stdout.

[Supervisor](http://supervisord.org/) is used to start varnishd (and optionally the sshd) daemon when a docker container based on this image is run. To enable simple viewing of stdout for the sshd subprocess, supervisor-stdout is included. This allows you to see output from the supervisord controlled subprocesses with `docker logs <docker-container-name>`.

If enabling and configuring SSH access, it is by public key authentication and, by default, the [Vagrant](http://www.vagrantup.com/) [insecure private key](https://github.com/mitchellh/vagrant/blob/master/keys/vagrant) is required.

### SSH Alternatives

SSH is not required in order to access a terminal for the running container. The simplest method is to use the docker exec command to run bash (or sh) as follows: 

```
$ docker exec -it <docker-name-or-id> bash
```

For cases where access to docker exec is not possible the preferred method is to use Command Keys and the nsenter command. See [command-keys.md](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/command-keys.md) for details on how to set this up.

## Quick Example

Run up a container named ```varnish.pool-1.1.1``` from the docker image ```jdeathe/centos-ssh-varnish``` on port 80 of your docker host. 1 backend host is defined with the IP address 172.17.8.101; this is required to identify the backend hosts from within the Varnish VCL file.

```
$ docker run -d \
  --privileged \
  --name varnish.pool-1.1.1 \
  -p 80:80 \
  --add-host backend-1:172.17.8.101 \
  jdeathe/centos-ssh-varnish:latest
```

Now you can verify it is initialised and running successfully by inspecting the container's logs.

```
$ docker logs varnish.pool-1.1.1
```

## Instructions

### (Optional) Configuration Data Volume

Create a "data volume" for configuration, this allows you to share the same configuration between multiple docker containers and, by mounting a host directory into the data volume you can override the default configuration files provided. The Configuration Volume is then used to provide access to the common configuration directories and files required by the service by way of the "```--volumes-from``` Docker run command.

Each service that requires a common set of configuration files should use a single Configuration Volume as illustrated in the following diagram:

```
+---------------------------------------------------+
|                (Docker Host system)               |
|                                                   |
| /etc/service-config/<service-name>                |
|                         +                         |
|                         |                         |
|            +============*===========+             |
|            |  Configuration Volume  |             |
|            |    Service Container   |             |
|            +============*===========+             |
|                         |                         |
|         +---------------*---------------+         |
|         |               |               |         |
|   +=====*=====+   +=====*=====+   +=====*=====+   |
|   |  Service  |   |  Service  |   |  Service  |   |
|   | Container |   | Container |   | Container |   |
|   |    (1)    |   |    (2)    |   |    (n)    |   |
|   +===========+   +===========+   +===========+   |
+---------------------------------------------------+

```

Make a directory on the docker host for storing container configuration files. This directory needs to contain everything from the directory [etc/services-config](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/etc/services-config)

```
$ mkdir -p /etc/services-config/varnish.pool-1.1.1
```

Create the data volume, mounting the applicable docker host's configuration directories to the associated  */etc/services-config/* sub-directories in the docker container. Docker will pull the busybox:latest image if you don't already have it available locally.

If enabling the SSH service in the supervisor configuration you can define a persistent authorised key for SSH access by mounting the ssh.pool-1 directory and adding the key there.

```
$ docker run \
  --name volume-config.varnish.pool-1.1.1 \
  -v /etc/services-config/ssh.pool-1/ssh:/etc/services-config/ssh \
  -v /etc/services-config/varnish.pool-1.1.1/supervisor:/etc/services-config/supervisor \
  -v /etc/services-config/varnish.pool-1.1.1/varnish:/etc/services-config/varnish \
  busybox:latest \
  /bin/true
```

### Running

To run the a docker container from this image you can use the included [run.sh](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/run.sh) and [run.conf](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/run.conf) scripts. The helper script will stop any running container of the same name, remove it and run a new daemonised container on an unspecified host port. Alternatively you can use the following to make the service available on port 8000 of the docker host. 4 backend hosts are defined with the IP range 172.17.8.101 - 172.17.8.104.

```
$ docker stop varnish.pool-1.1.1 && \
  docker rm varnish.pool-1.1.1
$ docker run -d \
  --privileged \
  --name varnish.pool-1.1.1 \
  -p 8000:80 \
  -p 8500:8443 \
  --add-host backend-1:172.17.8.101 \
  --add-host backend-2:172.17.8.102 \
  --add-host backend-3:172.17.8.103 \
  --add-host backend-4:172.17.8.104 \
  --volumes-from volume-config.varnish.pool-1.1.1 \
  jdeathe/centos-ssh-varnish:latest
```

Now you can verify it is initialised and running successfully by inspecting the container's logs:

```
$ docker logs varnish.pool-1.1.1
```

### Custom Configuration

If using the optional data volume for container configuration you are able to customise the configuration. In the following examples your custom docker configuration files should be located on the Docker host under the directory ```/etc/service-config/<container-name>/``` where ```<container-name>``` should match the applicable container name such as "varnish.pool-1.1.1" in the examples.

#### [varnish/docker-default.vcl](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/etc/services-config/varnish/docker-default.vcl)

Varnish can be configured via the docker-default.vcl.

#### [supervisor/supervisord.conf](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/etc/services-config/supervisor/supervisord.conf)

The supervisor service's configuration can also be overridden by editing the custom supervisord.conf file. It shouldn't be necessary to change the existing configuration here but you could include more [program:x] sections to run additional commands at startup.