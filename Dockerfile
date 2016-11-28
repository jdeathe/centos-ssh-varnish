# =============================================================================
# jdeathe/centos-ssh-varnish
#
# CentOS-6, Varnish 4.1
#
# =============================================================================
FROM jdeathe/centos-ssh:centos-6-1.7.3

MAINTAINER James Deathe <james.deathe@gmail.com>

# -----------------------------------------------------------------------------
# Install Varnish Cache
# -----------------------------------------------------------------------------
RUN rpm --rebuilddb \
	&& rpm --nosignature \
		-i https://repo.varnish-cache.org/redhat/varnish-4.1.el6.rpm \
	&& yum --setopt=tsflags=nodocs -y install \
		varnish-4.1.3-1.el6 \
	&& yum versionlock add \
		varnish* \
	&& rm -rf /var/cache/yum/* \
	&& yum clean all

# -----------------------------------------------------------------------------
# Copy files into place
# -----------------------------------------------------------------------------
ADD usr/sbin/varnishd-wrapper \
	/usr/sbin/
ADD opt/scmi \
	/opt/scmi/
ADD etc/services-config/supervisor/supervisord.d \
	/etc/services-config/supervisor/supervisord.d/
ADD etc/services-config/varnish/docker-default.vcl \
	/etc/services-config/varnish/
ADD etc/systemd/system \
	/etc/systemd/system/

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
	VARNISH_MAX_THREADS="1000" \
	VARNISH_MIN_THREADS="50" \
	VARNISH_STORAGE="file,/var/lib/varnish/varnish_storage.bin,1G" \
	VARNISH_THREAD_TIMEOUT="120" \
	VARNISH_TTL="120" \
	VARNISH_VCL_CONF="/etc/varnish/docker-default.vcl"

# -----------------------------------------------------------------------------
# Set image metadata
# -----------------------------------------------------------------------------
ARG RELEASE_VERSION="1.3.1"
LABEL \
	install="docker run \
--rm \
--privileged \
--volume /:/media/root \
jdeathe/centos-ssh-varnish:centos-6-${RELEASE_VERSION} \
/usr/sbin/scmi install \
--chroot=/media/root \
--name=\${NAME} \
--tag=centos-6-${RELEASE_VERSION}" \
	uninstall="docker run \
--rm \
--privileged \
--volume /:/media/root \
jdeathe/centos-ssh-varnish:centos-6-${RELEASE_VERSION} \
/usr/sbin/scmi uninstall \
--chroot=/media/root \
--name=\${NAME} \
--tag=centos-6-${RELEASE_VERSION}" \
	org.deathe.name="centos-ssh-varnish" \
	org.deathe.version="${RELEASE_VERSION}" \
	org.deathe.release="jdeathe/centos-ssh-varnish:centos-6-${RELEASE_VERSION}" \
	org.deathe.license="MIT" \
	org.deathe.vendor="jdeathe" \
	org.deathe.url="https://github.com/jdeathe/centos-ssh-varnish" \
	org.deathe.description="CentOS-6 6.8 x86_64 - Varnish Cache 4.1."

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]