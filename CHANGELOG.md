# Change Log

## centos-7

Summary of release changes for Version 2.

CentOS-7 7.5.1804 x86_64 - Varnish Cache 6.1.

### 2.3.0 - Unreleased

- Updates `gcc` package to gcc-4.8.5-36.el7_6.1.
- Updates source image to [2.5.1](https://github.com/jdeathe/centos-ssh/releases/tag/2.5.1).
- Updates and restructures Dockerfile.
- Updates container naming conventions and readability of `Makefile`.
- Fixes issue with unexpected published port in run templates when `DOCKER_PORT_MAP_TCP_80` or `DOCKER_PORT_MAP_TCP_8443` is set to an empty string or 0.
- Fixes binary paths in systemd unit files for compatibility with both EL and Ubuntu hosts.
- Adds consideration for event lag into test cases for unhealthy health_status events.
- Adds port incrementation to Makefile's run template for container names with an instance suffix.
- Adds placeholder replacement of `RELEASE_VERSION` docker argument to systemd service unit template.
- Adds improvement to pull logic in systemd unit install template.
- Adds `SSH_AUTOSTART_SUPERVISOR_STDOUT` with a value "false", disabling startup of `supervisor_stdout`.
- Adds error messages to healthcheck script and includes supervisord check.
- Adds improved logging output.
- Adds docker-compose configuration example.
- Adds improved/simplified Cookie logic in `docker-default.vcl`.
- Removes use of `/etc/services-config` paths.
- Removes the unused group element from the default container name.
- Removes the node element from the default container name.
- Removes unused environment variables from Makefile and scmi configuration.
- Removes X-Fleet section from etcd register template unit-file.

### 2.2.1 - 2018-12-10

- Fixes typo in test; using `--format` instead of `--filter`.
- Updates source image to [2.4.1](https://github.com/jdeathe/centos-ssh/releases/tag/2.4.1).
- Updates Varnish to [6.1.1](https://github.com/varnishcache/varnish-cache/blob/varnish-6.1.1/doc/changes.rst).
- Updates `gcc` packages to 4.8.5-36.
- Updates image versions in docker-compose example and tests.
- Adds required `--sysctl` settings to docker run templates.
- Adds change to ensure varnishncsa is run with a non-root user `varnishlog`.
- Adds varnishncsa access logs to docker log output.
- Adds "Varnish Details" to docker log output.

### 2.2.0 - 2018-10-09

- Updates Varnish to [6.1.0](https://github.com/varnishcache/varnish-cache/blob/varnish-6.1.0/doc/changes.rst)
- Adds lockfile to ensure varnishd is started before running varnishncsa.
- Adds failure messages to healthcheck script.

### 2.1.0 - 2018-10-01

- Updates source image to [2.4.0](https://github.com/jdeathe/centos-ssh/releases/tag/2.4.0).
- Updates Varnish to [6.0.1](https://github.com/varnishcache/varnish-cache/blob/varnish-6.0.1/doc/changes.rst)
- Updates pattern for static assets to include web fonts and SVG images and remove SWF.
- Removes response header that indicate Varnish version.
- Adds `VARNISH_AUTOSTART_VARNISHD_WRAPPER` for disabling varnishd autostart.
- Adds `VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER` to enable access logs.
- Adds `VARNISH_VARNISHNCSA_FORMAT` set the access log format string.

### 2.0.0 - 2018-06-22

- Initial release