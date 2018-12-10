# =============================================================================
# jdeathe/centos-ssh-varnish
#
# CentOS-7, Varnish 6.1
#
# =============================================================================
FROM jdeathe/centos-ssh:2.4.1

# -----------------------------------------------------------------------------
# Install Varnish Cache
# -----------------------------------------------------------------------------
RUN { \
		echo '[varnishcache_varnish61]'; \
		echo 'name=varnishcache_varnish61'; \
		echo 'baseurl=https://packagecloud.io/varnishcache/varnish61/el/7/$basearch'; \
		echo 'repo_gpgcheck=1'; \
		echo 'gpgcheck=0'; \
		echo 'enabled=1'; \
		echo 'gpgkey=https://packagecloud.io/varnishcache/varnish61/gpgkey'; \
		echo 'sslverify=1'; \
		echo 'sslcacert=/etc/pki/tls/certs/ca-bundle.crt'; \
		echo 'metadata_expire=300'; \
	} > /etc/yum.repos.d/varnishcache_varnish61.repo \
	&& yum -y install \
		--setopt=tsflags=nodocs \
		--disableplugin=fastestmirror \
		gcc-4.8.5-36.el7 \
		varnish-6.1.1-1.el7 \
	&& yum versionlock add \
		varnish \
		gcc \
	&& rm -rf /var/cache/yum/* \
	&& yum clean all

# -----------------------------------------------------------------------------
# Copy files into place
# -----------------------------------------------------------------------------
ADD src/usr/bin \
	/usr/bin/
ADD src/usr/sbin \
	/usr/sbin/
ADD src/opt/scmi \
	/opt/scmi/
ADD src/etc/services-config/supervisor/supervisord.d \
	/etc/services-config/supervisor/supervisord.d/
ADD src/etc/services-config/varnish/docker-default.vcl \
	/etc/services-config/varnish/
ADD src/etc/systemd/system \
	/etc/systemd/system/

RUN ln -sf \
		/etc/services-config/supervisor/supervisord.d/varnishd-wrapper.conf \
		/etc/supervisord.d/varnishd-wrapper.conf \
	&& ln -sf \
		/etc/services-config/supervisor/supervisord.d/varnishncsa-wrapper.conf \
		/etc/supervisord.d/varnishncsa-wrapper.conf \
	&& ln -sf \
		/etc/services-config/varnish/docker-default.vcl \
		/etc/varnish/docker-default.vcl \
	&& chmod 644 \
		/etc/varnish/*.vcl \
	&& chmod 700 \
		/usr/{bin/healthcheck,sbin/{varnishd,varnishncsa}-wrapper} \
	&& chmod 750 \
		/usr/sbin/varnishncsa-wrapper \
	&& chgrp varnish \
		/usr/sbin/varnishncsa-wrapper \
	&& mkdir -p \
		/var/run/varnish \
	&& chown \
		varnishlog:varnish \
		/var/run/varnish

EXPOSE 80 8443

# -----------------------------------------------------------------------------
# Set default environment variables
# -----------------------------------------------------------------------------
ENV SSH_AUTOSTART_SSHD="false" \
	SSH_AUTOSTART_SSHD_BOOTSTRAP="false" \
	VARNISH_AUTOSTART_VARNISHD_WRAPPER="true" \
	VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER="false" \
	VARNISH_MAX_THREADS="1000" \
	VARNISH_MIN_THREADS="50" \
	VARNISH_STORAGE="file,/var/lib/varnish/varnish_storage.bin,1G" \
	VARNISH_THREAD_TIMEOUT="120" \
	VARNISH_TTL="120" \
	VARNISH_VARNISHNCSA_FORMAT="%h %l %u %t \"%r\" %s %b \"%{Referer}i\" \"%{User-agent}i\"" \
	VARNISH_VCL_CONF="/etc/varnish/docker-default.vcl"

# -----------------------------------------------------------------------------
# Set image metadata
# -----------------------------------------------------------------------------
ARG RELEASE_VERSION="2.2.1"
LABEL \
	maintainer="James Deathe <james.deathe@gmail.com>" \
	install="docker run \
--rm \
--privileged \
--volume /:/media/root \
jdeathe/centos-ssh-varnish:${RELEASE_VERSION} \
/usr/sbin/scmi install \
--chroot=/media/root \
--name=\${NAME} \
--tag=${RELEASE_VERSION}" \
	uninstall="docker run \
--rm \
--privileged \
--volume /:/media/root \
jdeathe/centos-ssh-varnish:${RELEASE_VERSION} \
/usr/sbin/scmi uninstall \
--chroot=/media/root \
--name=\${NAME} \
--tag=${RELEASE_VERSION}" \
	org.deathe.name="centos-ssh-varnish" \
	org.deathe.version="${RELEASE_VERSION}" \
	org.deathe.release="jdeathe/centos-ssh-varnish:${RELEASE_VERSION}" \
	org.deathe.license="MIT" \
	org.deathe.vendor="jdeathe" \
	org.deathe.url="https://github.com/jdeathe/centos-ssh-varnish" \
	org.deathe.description="CentOS-7 7.5.1804 x86_64 - Varnish Cache 6.1."

HEALTHCHECK \
	--interval=0.5s \
	--timeout=1s \
	--retries=4 \
	CMD ["/usr/bin/healthcheck"]

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]