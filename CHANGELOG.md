# Change Log

## centos-6

Summary of release changes for Version 1.

CentOS-6 6.10 x86_64 - Varnish Cache 4.1.

### 1.5.2 - Unreleased

- Fixes typo in test; using `--format` instead of `--filter`.
- Updates source image to [1.9.1](https://github.com/jdeathe/centos-ssh/releases/tag/1.9.1).

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