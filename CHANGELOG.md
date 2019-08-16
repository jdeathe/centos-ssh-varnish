# Change Log

## 1 - centos-6

Summary of release changes.

### 1.7.0 - 2019-08-16

- Updates source image to [1.11.0](https://github.com/jdeathe/centos-ssh/releases/tag/1.11.0).
- Updates CHANGELOG.md to simplify maintenance.
- Updates README.md to simplify contents and improve readability.
- Updates README-short.txt to apply to all image variants.
- Updates Dockerfile `org.deathe.description` metadata LABEL for consistency.
- Updates supervisord configuration to send error log output to stderr.
- Updates varnishd supervisord configuration file/priority to `80-varnishd-wrapper.conf`/`80`.
- Updates varnishncsa supervisord configuration file/priority to `50-varnishncsa-wrapper.conf`/`50`.
- Updates docker-compose example with redis session store replacing memcached for the apache-php service.
- Updates wrapper scripts timer to use UTC date timestamps.
- Updates backend probe window from 5 to 3 to reduce time to register an offline backend.
- Fixes docker host connection status check in Makefile.
- Fixes error when restarting/reloading varnishd.
- Adds `inspect`, `reload` and `top` Makefile targets.
- Adds improved `clean` Makefile target; includes exited containers and dangling images.
- Adds `SYSTEM_TIMEZONE` handling to Makefile, scmi, systemd unit and docker-compose templates.
- Adds system time zone validation to healthcheck.
- Adds lock/state file to wrapper scripts.
- Adds VCL to handle `/status` and `/varnish-status` for monitoring the backend and varnish respectively.
- Removes `VARNISH_AUTOSTART_VARNISHD_WRAPPER`, replaced with `ENABLE_VARNISHD_WRAPPER`.
- Removes `VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER`, replaced with `ENABLE_VARNISHNCSA_WRAPPER`.
- Removes support for long image tags (i.e. centos-6-1.x.x).

### 1.6.0 - 2019-05-06

- Updates source image to [1.10.1](https://github.com/jdeathe/centos-ssh/releases/tag/1.10.1).
- Updates Varnish to version [4.1.11](https://github.com/varnishcache/varnish-cache/blob/varnish-4.1.11/doc/changes.rst).
- Updates and restructures Dockerfile.
- Updates container naming conventions and readability of `Makefile`.
- Updates startup time to 4 seconds.
- Updates healthcheck retries to 5.
- Updates default VCL excluding several parts already defined in `builtin.vcl`.
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
- Adds improved `healtchcheck`, `varnishd-wrapper` and `varnishncsa-wrapper` scripts.
- Adds improved lock/state file implementation in wrapper scripts.
- Adds `VARNISH_OPTIONS` and `VARNISH_VARNISHNCSA_OPTIONS`.
- Adds improved VCL error checking/handling.
- Adds styled synthetic 500 error responses.
- Removes use of `/etc/services-config` paths.
- Removes the unused group element from the default container name.
- Removes the node element from the default container name.
- Removes unused environment variables from Makefile and scmi configuration.
- Removes X-Fleet section from etcd register template unit-file.

### 1.5.2 - 2018-12-10

- Fixes typo in test; using `--format` instead of `--filter`.
- Updates source image to [1.9.1](https://github.com/jdeathe/centos-ssh/releases/tag/1.9.1).
- Updates image versions in docker-compose example and tests.
- Adds required `--sysctl` settings to docker run templates.
- Adds change to ensure varnishncsa is run with a non-root user `varnishlog`.
- Adds varnishncsa access logs to docker log output.
- Adds "Varnish Details" to docker log output.

### 1.5.1 - 2018-10-09

- Adds lockfile to ensure varnishd is started before varnishncsa.
- Adds failure messages to healthcheck script.

### 1.5.0 - 2018-10-01

- Updates `gcc` package to 4.4.7-23.
- Updates source image to [1.9.0](https://github.com/jdeathe/centos-ssh/releases/tag/1.9.0).
- Updates pattern for static assets to include web fonts and SVG images and remove SWF.
- Removes response header that indicate Varnish version.
- Adds `VARNISH_AUTOSTART_VARNISHD_WRAPPER` for disabling varnishd autostart.
- Adds `VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER` to enable access logs.
- Adds `VARNISH_VARNISHNCSA_FORMAT` set the access log format string.

### 1.4.4 - 2018-06-22

- Adds docker-compose example.
- Updates README with details of Version 2.

### 1.4.3 - 2018-05-22

- Updates source image to [1.8.4 tag](https://github.com/jdeathe/centos-ssh/releases/tag/1.8.4).
- Updates varnish to version 4.1.10.

### 1.4.2 - 2018-01-16

- Updates source image to [1.8.3 tag](https://github.com/jdeathe/centos-ssh/releases/tag/1.8.3).
- Adds generic ready state test function.
- Adds a `.dockerignore` file.
- Adds httpoxy mitigation.

### 1.4.1 - 2017-09-16

- Updates varnish to version 4.1.8.
- Adds use of readonly variables for scmi constants.
- Updates source image to [1.8.2 tag](https://github.com/jdeathe/centos-ssh/releases/tag/1.8.2).

### 1.4.0 - 2017-08-03

- Adds `SHPEC_ROOT` variable to Makefile.
- Fixes issue with expect script failure when using `expect -f`.
- Removes scmi; it's maintained [upstream](https://github.com/jdeathe/centos-ssh/blob/centos-6/src/usr/sbin/scmi).
- Adds use of readonly variables for constants.
- Updates varnish to version 4.1.7.
- Replaces deprecated Dockerfile `MAINTAINER` with a `LABEL`.
- Updates source image to [1.8.1 tag](https://github.com/jdeathe/centos-ssh/releases/tag/1.8.1).
- Adds a `src` directory for the image root files.
- Adds `STARTUP_TIME` variable for the `logs-delayed` Makefile target.
- Adds test case output with improved readability.
- Adds healthcheck.
- Adds better test method for verification of running Varnish parameters.

### 1.3.2 - 2017-04-26

- Updates source image to [1.7.6 tag](https://github.com/jdeathe/centos-ssh/releases/tag/1.7.6).
- Updates Varnish to version 4.1.5.
- Adds separation of HTTP and HTTPS content cache.
- Adds a well formed request for backend health.
- Adds a change log (`CHANGELOG.md`).
- Adds support for semantic version numbered tags.
- Adds minor code style changes to the Makefile for readability.
- Adds support for running `shpec` functional tests with `make test`.
- Adds gcc - a Varnish dependency not handled by the rpm.

### 1.3.1 - 2016-11-28

- Removes unused variables from Dockerfile:
  - `VARNISH_ADMIN_LISTEN_ADDRESS`
  - `VARNISH_ADMIN_LISTEN_PORT`
  - `VARNISH_LISTEN_ADDRESS`
  - `VARNISH_LISTEN_PORT`
  - `VARNISH_PIDFILE`
  - `VARNISH_SECRET_FILE`
- Adds correction to Varnish Documentation URLs.
- Adds correction to the example tag URL.
- Adds PROXY protocol to the 8443 port binding.
- Removes grace header which is used for debugging.
- Removes duplicated X-Forwarded-For handling - unnecessary since Varnish 4 moved logic out of the default VCL configuration and leaving it in place results in duplicate entries in X-Forwarded-For.

### 1.3.0 - 2016-11-21

- Adds update to CentOS-6.8 with source (jdeathe/centos-ssh:centos-6-1.7.3).
- Adds Varnish 4.1 + updated default configuration.
- Adds support for SCMI install/uninstall methods with docker, systemd or fleet service managers.
- Adds option to set VCL configuration from base64 encoded string.
- Removes requirement to run in privileged mode. Use of --ulimit docker parameter is now used to define the limits for `memlock`, `nofile` and `nproc`.
- Removes environment variables for varnishd settings that are constants. `VARNISH_ADMIN_LISTEN_ADDRESS`, `VARNISH_ADMIN_LISTEN_PORT`, `VARNISH_LISTEN_ADDRESS`, `VARNISH_LISTEN_PORT`,  `VARNISH_PIDFILE` and `VARNISH_SECRET_FILE`.

### 1.2.0 - 2015-12-29

- Updates CentOS from 6.6 to 6.7.
- Adds support for configuration volume in run.sh helper.
- Maintenance of the helper scripts.
- Updates upstream image to centos-6-1.4.0 tag instead of the centos-6 branch. Now at CentOS 6.7.
- Change to use specific package versions to improve build reproducibility. Varnish cache 3.0.7.
- Updates systemd definition and installer scripts. Still requires manual steps to define cluster backend (node) IP addresses but should work out of the box for a single node CoreOS host.
- Adds smarter default backend host configuration and defaults within the run.sh helper scripts.

### 1.1.0 - 2015-05-20

- Updates CentOS from 6.5 to 6.6.
- Adds MIT License.

### 1.0.0 - 2015-01-30

- Initial release