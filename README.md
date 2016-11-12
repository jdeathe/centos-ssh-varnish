centos-ssh-varnish
==================

Docker Image including CentOS-6 6.8 x86_64 and Varnish Cache 3.0.

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

To run the a docker container from this image you can use the included [run.sh](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/run.sh) and [run.conf](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/run.conf) scripts. The helper script will stop any running container of the same name, remove it and run a new daemonised container on an unspecified host port. Alternatively you can use the following to make the http service available on port 8000 and offloaded https on port 8500 of the docker host. The environment variable ```VARNISH_STORAGE``` has been used to set up a 256M memory based storage instead of the default file based type.

#### Using environment variables

```
$ docker stop varnish.pool-1.1.1 && \
  docker rm varnish.pool-1.1.1
$ docker run -d \
  --privileged \
  --name varnish.pool-1.1.1 \
  -p 8000:80 \
  -p 8500:8443 \
  --env "VARNISH_STORAGE=malloc,256M" \
  --add-host backend-1:172.17.8.101 \
  jdeathe/centos-ssh-varnish:latest
```

#### Using configuration volume

By default a single backend host is required. In this example 3 backend hosts are defined with the IP range 172.17.8.101 - 172.17.8.103. In this case the docker-default.vcl would require updating to handle more than one backend host as described in the [Custom Configuration](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/README.md#custom-configuration) section below.

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
  --volumes-from volume-config.varnish.pool-1.1.1 \
  jdeathe/centos-ssh-varnish:latest
```

Now you can verify it is initialised and running successfully by inspecting the container's logs:

```
$ docker logs varnish.pool-1.1.1
```

#### Runtime Environment Variables

There are several environmental variables defined at runtime which allows the operator to customise the running container. This may become necessary under special circumstances and the following show those that are most likely to be considered for review, the rest should be left unaltered and for clarification refer to the [varnishd documentation](https://www.varnish-cache.org/docs/3.0/reference/varnishd.html).

##### 1. (-a) VARNISH_LISTEN_ADDRESS & VARNISH_LISTEN_PORT

```VARNISH_LISTEN_ADDRESS``` is set to 0.0.0.0 by default and should not be altered. VARNISH_LISTEN_PORT has been used to add the listening port 80 and also to set a second listening address and port of 0.0.0.0:8448 for the special case of HTTPS traffic that has been terminated by an upstream load-balancer.

##### 2. (-P) VARNISH_PIDFILE

This should not be changed and will be ignored if set. The varnish-start script will set the PID file to the default /var/run/varnish.pid file.

##### 3. (-f) VARNISH_VCL_CONF

The Varnish VLC configuration file to load is set using ```VARNISH_VCL_CONF```. The default configuration supplied is located at the path /etc/varnish/docker-default.vcl and an alternative example is also available under /etc/varnish/docker-cluster.vcl.

##### 4. (-t) VARNISH_TTL

The ```VARNISH_TTL``` can be used to set a hard minimum time to live for cached documents. The default is 120 seconds.

##### 5. (-w) VARNISH_MIN_THREADS, VARNISH_MAX_THREADS & VARNISH_THREAD_TIMEOUT

Start at least ```VARNISH_MIN_THREADS``` but no more than ```VARNISH_MAX_THREADS``` worker threads with the ```VARNISH_THREAD_TIMEOUT``` idle timeout.

##### 6. (-s) VARNISH_STORAGE

Use ```VARNISH_STORAGE``` to specify the storage backend. See the [varnishd documentation](https://www.varnish-cache.org/docs/3.0/reference/varnishd.html#storage-types) for the types and parameters available. The default is a file type backend but it is recommended to use malloc if there is enough RAM available.

### Custom Configuration

If using the optional data volume for container configuration you are able to customise the configuration. In the following examples your custom docker configuration files should be located on the Docker host under the directory ```/etc/service-config/<container-name>/``` where ```<container-name>``` should match the applicable container name such as "varnish.pool-1.1.1" in the examples.

#### [varnish/docker-default.vcl](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/etc/services-config/varnish/docker-default.vcl)

Varnish can be configured via the docker-default.vcl.

#### [varnish/docker-cluster.vcl](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/etc/services-config/varnish/docker-cluster.vcl)

An example of a Varnish configuration that uses 3 backend host nodes.

#### [supervisor/supervisord.conf](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/etc/services-config/supervisor/supervisord.conf)

The supervisor service's configuration can also be overridden by editing the custom supervisord.conf file. It shouldn't be necessary to change the existing configuration here but you could include more [program:x] sections to run additional commands at startup.