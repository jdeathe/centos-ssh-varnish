FROM jdeathe/centos-ssh:2.5.1

ARG RELEASE_VERSION="2.2.1"

# ------------------------------------------------------------------------------
# Base install of required packages
# ------------------------------------------------------------------------------
RUN { printf -- \
		'[%s]\nname=%s\nbaseurl=%s\nrepo_gpgcheck=%s\ngpgcheck=%s\nenabled=%s\ngpgkey=%s\nsslverify=%s\nsslcacert=%s\nmetadata_expire=%s\n' \
		'varnishcache_varnish61' \
		'varnishcache_varnish61' \
		'https://packagecloud.io/varnishcache/varnish61/el/7/$basearch' \
		'1' \
		'0' \
		'1' \
		'https://packagecloud.io/varnishcache/varnish61/gpgkey' \
		'1' \
		'/etc/pki/tls/certs/ca-bundle.crt' \
		'300'; \
	} > /etc/yum.repos.d/varnishcache_varnish61.repo \
	&& yum -y install \
		--setopt=tsflags=nodocs \
		--disableplugin=fastestmirror \
		gcc-4.8.5-36.el7_6.1 \
		varnish-6.1.1-1.el7 \
	&& yum versionlock add \
		varnish \
		gcc \
	&& rm -rf /var/cache/yum/* \
	&& yum clean all

# ------------------------------------------------------------------------------
# Copy files into place
# ------------------------------------------------------------------------------
ADD src /

# ------------------------------------------------------------------------------
# Provisioning
# - Replace placeholders with values in systemd service unit template
# - Symbolic link varnish access log file to stdout
# - Create directory for varnishncsa PID file
# - Set permissions
# ------------------------------------------------------------------------------
RUN sed -i \
		-e "s~{{RELEASE_VERSION}}~${RELEASE_VERSION}~g" \
		/etc/systemd/system/centos-ssh-varnish@.service \
	&& mkdir -p \
		/var/{lib/misc,lock/subsys,run}/varnish \
	&& chown \
		varnishlog:varnish \
		/var/{lib/misc,lock/subsys,run}/varnish \
	&& chmod 644 \
		/etc/varnish/*.vcl \
	&& chmod 700 \
		/usr/{bin/healthcheck,sbin/{varnishd,varnishncsa}-wrapper} \
	&& chmod 750 \
		/usr/sbin/varnishncsa-wrapper \
	&& chgrp varnish \
		/usr/sbin/varnishncsa-wrapper

EXPOSE 80 8443

# ------------------------------------------------------------------------------
# Set default environment variables
# ------------------------------------------------------------------------------
ENV SSH_AUTOSTART_SSHD="false" \
	SSH_AUTOSTART_SSHD_BOOTSTRAP="false" \
	SSH_AUTOSTART_SUPERVISOR_STDOUT="false" \
	VARNISH_AUTOSTART_VARNISHD_WRAPPER="true" \
	VARNISH_AUTOSTART_VARNISHNCSA_WRAPPER="false" \
	VARNISH_MAX_THREADS="1000" \
	VARNISH_MIN_THREADS="50" \
	VARNISH_STORAGE="file,/var/lib/varnish/varnish_storage.bin,1G" \
	VARNISH_THREAD_TIMEOUT="120" \
	VARNISH_TTL="120" \
	VARNISH_VARNISHNCSA_FORMAT="%h %l %u %t \"%r\" %s %b \"%{Referer}i\" \"%{User-agent}i\"" \
	VARNISH_VCL_CONF="/etc/varnish/docker-default.vcl"

# ------------------------------------------------------------------------------
# Set image metadata
# ------------------------------------------------------------------------------
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
	--interval=1s \
	--timeout=1s \
	--retries=2 \
	CMD ["/usr/bin/healthcheck"]

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]
