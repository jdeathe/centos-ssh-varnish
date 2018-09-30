# Change Log

## centos-7

Summary of release changes for Version 2.

CentOS-7 7.5.1804 x86_64 - Varnish Cache 6.0.

### 2.1.0 - Unreleased

- Updates source image to [2.4.0](https://github.com/jdeathe/centos-ssh/releases/tag/2.4.0).
- Updates Varnish to [6.0.1](https://github.com/varnishcache/varnish-cache/blob/varnish-6.0.1/doc/changes.rst)
- Updates pattern for static assets to include web fonts and SVG images and remove SWF.
- Removes response header that indicate Varnish version.
- Adds `VARNISH_AUTOSTART_VARNISHD_WRAPPER` for disabling varnishd autostart.
- Adds `VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER` to enable access logs.
- Adds `VARNISH_VARNISHNCSA_FORMAT` to format the content of access logs.

### 2.0.0 - 2018-06-22

- Initial release