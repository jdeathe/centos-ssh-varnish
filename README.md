### Tags and respective `Dockerfile` links

- [`2.4.1`](https://github.com/jdeathe/centos-ssh-varnish/releases/tag/2.4.1), `centos-7` [(centos-7/Dockerfile)](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-7/Dockerfile)
- [`1.7.1`](https://github.com/jdeathe/centos-ssh-varnish/releases/tag/1.7.1), `centos-6` [(centos-6/Dockerfile)](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6/Dockerfile)

## Overview

This build uses the base image [jdeathe/centos-ssh](https://github.com/jdeathe/centos-ssh) so inherits it's features but with `sshd` disabled by default. [Supervisor](http://supervisord.org/) is used to start the varnishd (and optionally the varnishncsa) daemon when a docker container based on this image is run.

### Image variants

- [Varnish Cache 6.2 - CentOS-7](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-7)
- [Varnish Cache 4.1 - CentOS-6](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-6)

## Quick start

> For production use, it is recommended to select a specific release tag as shown in the examples.

Run up a container named `varnish.1` from the docker image `jdeathe/centos-ssh-varnish` on port 80 of your docker host. 1 backend host is defined mapping the host `httpd_1` to the IP address `172.17.8.101`; this is required to identify the backend host that's defined in the default Varnish VCL file.

> Change `172.17.8.101` in the example below to an IP address that resolves to a valid web server on your network.

```
$ docker run -d -t \
  --name varnish.1 \
  -p 80:80 \
  --sysctl "net.core.somaxconn=1024" \
  --add-host httpd_1:172.17.8.101 \
  jdeathe/centos-ssh-varnish:2.4.1
```

Verify the named container's process status and health.

```
$ docker ps -a \
  -f "name=varnish.1"
```

Verify successful initialisation of the named container.

```
$ docker logs varnish.1
```

## Instructions

### Running

To run the a docker container from this image you can use the standard docker commands as shown in the example below. Alternatively, there's a [docker-compose](https://github.com/jdeathe/centos-ssh-varnish/blob/centos-7/docker-compose.yml) example.

For production use, it is recommended to select a specific release tag as shown in the examples.

In the following example the http service is bound to port 8000 and offloaded https on port 8500 of the docker host. Also, the environment variable `VARNISH_STORAGE` has been used to set up a 256M memory based storage instead of the default file based type.

#### Using environment variables

```
$ docker stop varnish.1 && \
  docker rm varnish.1; \
  docker run \
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
  jdeathe/centos-ssh-varnish:2.4.1
```

Now you can verify it is initialised and running successfully by inspecting the container's logs:

```
$ docker logs varnish.1
```

#### Environment variables

There are several environmental variables defined at runtime which allows the operator to customise the running container. This may become necessary under special circumstances and the following show those that are most likely to be considered for review, the rest should be left unaltered and for clarification refer to the [varnishd documentation](https://www.varnish-cache.org/docs/4.1/index.html).

##### ENABLE_VARNISHD_WRAPPER

It may be desirable to prevent the startup of the varnishd-wrapper script. For example, when using an image built from this Dockerfile as the source for another Dockerfile you could disable varnishd from startup by setting `ENABLE_VARNISHD_WRAPPER` to `false`.

##### ENABLE_VARNISHNCSA_WRAPPER

Controls the startup of the varnishncsa-wrapper script which is not started by default. With `ENABLE_VARNISHNCSA_WRAPPER` set to `true` the `varnishncsa` process is started to output the Varnish in-memory logs to the log file `/var/log/varnish/access_log`. Logs are in Apache / NCSA combined log format unless altered using `VARNISH_VARNISHNCSA_FORMAT`.

##### VARNISH_MIN_THREADS, VARNISH_MAX_THREADS & VARNISH_THREAD_TIMEOUT

Start at least `VARNISH_MIN_THREADS` but no more than `VARNISH_MAX_THREADS` worker threads with the `VARNISH_THREAD_TIMEOUT` idle timeout.

##### VARNISH_OPTIONS

Use `VARNISH_OPTIONS` to set other `varnishd` options.

##### VARNISH_STORAGE

Use `VARNISH_STORAGE` to specify the storage backend. See the [varnishd documentation](https://varnish-cache.org/docs/4.1/reference/varnishd.html#storage-backend) for the types and parameters available. The default is a file type backend but it is recommended to use malloc if there is enough RAM available.

##### VARNISH_TTL

The `VARNISH_TTL` can be used to set a hard minimum time to live for cached documents. The default is 120 seconds.

##### VARNISH_VARNISHNCSA_FORMAT

When `ENABLE_VARNISHNCSA_WRAPPER` is set to `true` then `VARNISH_VARNISHNCSA_FORMAT` can be used to set the output log [format string](https://varnish-cache.org/docs/6.0/reference/varnishncsa.html#format).

##### VARNISH_VARNISHNCSA_OPTIONS

Use `VARNISH_VARNISHNCSA_OPTIONS` to set other `varnishncsa` options.

##### VARNISH_VCL_CONF

The Varnish VCL configuration file path, (or base64 encoded string of the configuration file contents), is set using `VARNISH_VCL_CONF`. The default configuration supplied is located at the path `/etc/varnish/docker-default.vcl`.
