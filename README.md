centos-ssh-varnish
==================

Docker Image including:
- CentOS-6 6.10 x86_64 and Varnish Cache 4.1.
- CentOS-7 7.5.1804 x86_64 and Varnish Cache 6.1.

## Overview & links

- `centos-7`, `centos-7-2.2.1`, `2.2.1` [(centos-7/Dockerfile)](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-7/Dockerfile)
- `centos-6`, `centos-6-1.5.2`, `1.5.2` [(centos-6/Dockerfile)](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/Dockerfile)

#### centos-6

The latest CentOS-6 based release can be pulled from the `centos-6` Docker tag. It is recommended to select a specific release tag - the convention is `centos-6-1.5.2`or `1.5.2` for the [1.5.2](https://github.com/jdeathe/centos-ssh-varnish/tree/1.5.2) release tag.

#### centos-7

The latest CentOS-7 based release can be pulled from the `centos-7` Docker tag. It is recommended to select a specific release tag - the convention is `centos-7-2.2.1`or `2.2.1` for the [2.2.1](https://github.com/jdeathe/centos-ssh-varnish/tree/2.2.1) release tag.

Included in the build are the [SCL](https://www.softwarecollections.org/), [EPEL](http://fedoraproject.org/wiki/EPEL) and [IUS](https://ius.io) repositories. Installed packages include [OpenSSH](http://www.openssh.com/portable.html) secure shell, [vim-minimal](http://www.vim.org/), are installed along with python-setuptools, [supervisor](http://supervisord.org/) and [supervisor-stdout](https://github.com/coderanger/supervisor-stdout).

Supervisor is used to start the varnishd (and optionally the sshd) daemon when a docker container based on this image is run. To enable simple viewing of stdout for the service's subprocess, supervisor-stdout is included. This allows you to see output from the supervisord controlled subprocesses with `docker logs {docker-container-name}`.

If enabling and configuring SSH access, it is by public key authentication and, by default, the [Vagrant](http://www.vagrantup.com/) [insecure private key](https://github.com/mitchellh/vagrant/blob/master/keys/vagrant) is required.

### SSH Alternatives

SSH is not required in order to access a terminal for the running container. The simplest method is to use the docker exec command to run bash (or sh) as follows: 

```
$ docker exec -it {docker-name-or-id} bash
```

For cases where access to docker exec is not possible the preferred method is to use Command Keys and the nsenter command. See [command-keys.md](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/command-keys.md) for details on how to set this up.

## Quick Example

Run up a container named `varnish.1` from the docker image `jdeathe/centos-ssh-varnish` on port 80 of your docker host. 1 backend host is defined with the IP address 172.17.8.101; this is required to identify the backend hosts from within the Varnish VCL file.

```
$ docker run -d -t \
  --name varnish.1 \
  -p 80:80 \
  --sysctl "net.core.somaxconn=1024" \
  --add-host httpd_1:172.17.8.101 \
  jdeathe/centos-ssh-varnish:2.2.1
```

Now you can verify it is initialised and running successfully by inspecting the container's logs.

```
$ docker logs varnish.1
```

## Instructions

### Running

To run the a docker container from this image you can use the standard docker commands. Alternatively, if you have a checkout of the [source repository](https://github.com/jdeathe/centos-ssh-varnish), and have make installed the Makefile provides targets to build, install, start, stop etc. where environment variables can be used to configure the container options and set custom docker run parameters.

In the following example the http service is bound to port 8000 and offloaded https on port 8500 of the docker host. Also, the environment variable `VARNISH_STORAGE` has been used to set up a 256M memory based storage instead of the default file based type.

#### Using environment variables

```
$ docker stop varnish.1 && \
  docker rm varnish.1
$ docker run \
  --detach \
  --tty \
  --name varnish.1 \
  --publish 8000:80 \
  --publish 8500:8443 \
  --sysctl "net.core.somaxconn=1024" \
  --sysctl "net.ipv4.ip_local_port_range=1024 65535" \
  --sysctl "net.ipv4.route.flush=1" \
  --ulimit memlock=82000 \
  --ulimit nofile=131072 \
  --ulimit nproc=65535 \
  --env "VARNISH_STORAGE=malloc,256M" \
  --env "VARNISH_MAX_THREADS=2000" \
  --env "VARNISH_MIN_THREADS=100" \
  --add-host httpd_1:172.17.8.101 \
  jdeathe/centos-ssh-varnish:2.2.1
```

Now you can verify it is initialised and running successfully by inspecting the container's logs:

```
$ docker logs varnish.1
```

#### Environment Variables

There are several environmental variables defined at runtime which allows the operator to customise the running container. This may become necessary under special circumstances and the following show those that are most likely to be considered for review, the rest should be left unaltered and for clarification refer to the [varnishd documentation](https://www.varnish-cache.org/docs/6.0/index.html).

##### VARNISH_AUTOSTART_VARNISHD_WRAPPER

It may be desirable to prevent the startup of the varnishd-wrapper script. For example, when using an image built from this Dockerfile as the source for another Dockerfile you could disable varnishd from startup by setting `VARNISH_AUTOSTART_VARNISHD_WRAPPER` to `false`.

##### VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER

Controls the startup of the varnishncsa-wrapper script which is not started by default. With `VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER` set to `true` the `varnishncsa` process is started to output the Varnish in-memory logs to the log file `/var/log/varnish/access_log`. Logs are in Apache / NCSA combined log format unless altered using `VARNISH_VARNISHNCSA_FORMAT`.

##### VARNISH_VCL_CONF

The Varnish VCL configuration file path, (or base64 encoded string of the configuration file contents), is set using `VARNISH_VCL_CONF`. The default configuration supplied is located at the path `/etc/varnish/docker-default.vcl`.

##### VARNISH_TTL

The `VARNISH_TTL` can be used to set a hard minimum time to live for cached documents. The default is 120 seconds.

##### VARNISH_MIN_THREADS, VARNISH_MAX_THREADS & VARNISH_THREAD_TIMEOUT

Start at least `VARNISH_MIN_THREADS` but no more than `VARNISH_MAX_THREADS` worker threads with the `VARNISH_THREAD_TIMEOUT` idle timeout.

##### VARNISH_STORAGE

Use `VARNISH_STORAGE` to specify the storage backend. See the [varnishd documentation](https://varnish-cache.org/docs/6.0/reference/varnishd.html#storage-backend) for the types and parameters available. The default is a file type backend but it is recommended to use malloc if there is enough RAM available.

##### VARNISH_VARNISHNCSA_FORMAT

When `VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER` is set to `true` then `VARNISH_VARNISHNCSA_FORMAT` can be used to set the output log [format string](https://varnish-cache.org/docs/6.0/reference/varnishncsa.html#format).
