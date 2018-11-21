# Change Log

## centos-7

Summary of release changes for Version 2.

CentOS-7 7.5.1804 x86_64 - Varnish Cache 6.1.

### 2.2.1 - Unreleased

- Fixes typo in test; using `--format` instead of `--filter`.
- Updates source image to [2.4.1](https://github.com/jdeathe/centos-ssh/releases/tag/2.4.1).
- Updates Varnish to [6.1.1](https://github.com/varnishcache/varnish-cache/blob/varnish-6.1.1/doc/changes.rst)
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