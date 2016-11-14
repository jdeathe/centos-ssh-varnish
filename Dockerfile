# =============================================================================
# jdeathe/centos-ssh-varnish
#
# CentOS-6, Varnish 3.0
#
# =============================================================================
FROM jdeathe/centos-ssh:centos-6-1.7.3

MAINTAINER James Deathe <james.deathe@gmail.com>

# -----------------------------------------------------------------------------
# Install Varnish Cache
# -----------------------------------------------------------------------------
RUN rpm --rebuilddb \
	&& rpm --nosignature \
		-Uvh http://repo.varnish-cache.org/redhat/varnish-3.0/el6/noarch/varnish-release/varnish-release-3.0-1.el6.noarch.rpm \
	&& yum --setopt=tsflags=nodocs -y install \
		varnish-3.0.7-1.el6 \
	&& yum versionlock add \
		varnish* \
	&& rm -rf /var/cache/yum/* \
	&& yum clean all

# -----------------------------------------------------------------------------
# Copy files into place
# -----------------------------------------------------------------------------
ADD usr/sbin/varnishd-wrapper \
	/usr/sbin/
ADD etc/services-config/supervisor/supervisord.d \
	/etc/services-config/supervisor/supervisord.d/
ADD etc/services-config/varnish/docker-default.vcl \
	/etc/services-config/varnish/

RUN ln -sf \
		/etc/services-config/supervisor/supervisord.d/varnishd-wrapper.conf \
		/etc/supervisord.d/varnishd-wrapper.conf \
	&& ln -sf \
		/etc/services-config/varnish/docker-default.vcl \
		/etc/varnish/docker-default.vcl \
	&& chmod 644 \
		/etc/varnish/*.vcl \
	&& chmod 700 \
		/usr/sbin/varnishd-wrapper

EXPOSE 80 8443

# -----------------------------------------------------------------------------
# Set default environment variables
# -----------------------------------------------------------------------------
ENV SSH_AUTOSTART_SSHD=false \
	SSH_AUTOSTART_SSHD_BOOTSTRAP=false \
	VARNISH_ADMIN_LISTEN_ADDRESS="127.0.0.1" \
	VARNISH_ADMIN_LISTEN_PORT="6082" \
	VARNISH_LISTEN_ADDRESS="0.0.0.0" \
	VARNISH_LISTEN_PORT="80,0.0.0.0:8443" \
	VARNISH_MAX_THREADS="1000" \
	VARNISH_MIN_THREADS="50" \
	VARNISH_PIDFILE="/var/run/varnish.pid" \
	VARNISH_SECRET_FILE="/etc/varnish/secret" \
	VARNISH_STORAGE="file,/var/lib/varnish/varnish_storage.bin,1G" \
	VARNISH_THREAD_TIMEOUT="120" \
	VARNISH_TTL="120" \
	VARNISH_VCL_CONF="/etc/varnish/docker-default.vcl"

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]