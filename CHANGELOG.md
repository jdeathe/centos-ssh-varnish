# Change Log

## 2 - centos-7

Summary of release changes.

### 2.5.0 - 2019-10-10

- Updates Varnish to [6.3.0](https://github.com/varnishcache/varnish-cache/blob/varnish-6.3.0/doc/changes.rst).
- Updates image tags in docker-compose example configuration.

### 2.4.1 - 2019-10-08

- Deprecate Makefile target `logs-delayed`; replaced with `logsdef`.
- Updates Varnish to [6.2.1](https://github.com/varnishcache/varnish-cache/blob/varnish-6.2.1/doc/changes.rst).
- Updates `gcc` package to 4.8.5-39.
- Updates startsecs for `varnishncsa-wrapper` to 5 seconds.
- Updates `test/health_status` helper script with for consistency.
- Updates Makefile target `logs` to accept `[OPTIONS]` (e.g `make -- logs -ft`).
- Updates info/error output for consistency.
- Updates healthcheck failure messages to remove EOL character that is rendered in status response.
- Updates ordering of Tags and respective Dockerfile links in README.md for readability.
- Adds improved test workflow; added `test-setup` target to Makefile.
- Adds Makefile target `logsdef` to handle deferred logs output within a target chain.
- Adds `/docs` directory for supplementary documentation and simplify README.
- Fixes validation failure of 0 second --timeout value in `test/health_status`.

### 2.4.0 - 2019-08-17

- Updates source image to [2.6.0](https://github.com/jdeathe/centos-ssh/releases/tag/2.6.0).
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
- Removes support for long image tags (i.e. centos-7-2.x.x).

### 2.3.0 - 2019-05-06

- Updates `gcc` package to gcc-4.8.5-36.el7_6.1.
- Updates source image to [2.5.1](https://github.com/jdeathe/centos-ssh/releases/tag/2.5.1).
- Updates Varnish to [6.2.0](https://github.com/varnishcache/varnish-cache/blob/varnish-6.2.0/doc/changes.rst).
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

- Updates Varnish to [6.1.0](https://github.com/varnishcache/varnish-cache/blob/varnish-6.1.0/doc/changes.rst).
- Adds lockfile to ensure varnishd is started before running varnishncsa.
- Adds failure messages to healthcheck script.

### 2.1.0 - 2018-10-01

- Updates source image to [2.4.0](https://github.com/jdeathe/centos-ssh/releases/tag/2.4.0).
- Updates Varnish to [6.0.1](https://github.com/varnishcache/varnish-cache/blob/varnish-6.0.1/doc/changes.rst).
- Updates pattern for static assets to include web fonts and SVG images and remove SWF.
- Removes response header that indicate Varnish version.
- Adds `VARNISH_AUTOSTART_VARNISHD_WRAPPER` for disabling varnishd autostart.
- Adds `VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER` to enable access logs.
- Adds `VARNISH_VARNISHNCSA_FORMAT` set the access log format string.

### 2.0.0 - 2018-06-22

- Initial release.