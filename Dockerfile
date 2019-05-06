FROM jdeathe/centos-ssh:1.10.1

ARG RELEASE_VERSION="1.5.2"

# ------------------------------------------------------------------------------
# Base install of required packages
# ------------------------------------------------------------------------------
RUN { printf -- \
		'[%s]\nname=%s\nbaseurl=%s\nrepo_gpgcheck=%s\ngpgcheck=%s\nenabled=%s\ngpgkey=%s\nsslverify=%s\nsslcacert=%s\nmetadata_expire=%s\n' \
		'varnishcache_varnish41' \
		'varnishcache_varnish41' \
		'https://packagecloud.io/varnishcache/varnish41/el/6/$basearch' \
		'1' \
		'0' \
		'1' \
		'https://packagecloud.io/varnishcache/varnish41/gpgkey' \
		'1' \
		'/etc/pki/tls/certs/ca-bundle.crt' \
		'300'; \
	} > /etc/yum.repos.d/varnishcache_varnish41.repo \
	&& yum -y install \
		--setopt=tsflags=nodocs \
		--disableplugin=fastestmirror \
		gcc-4.4.7-23.el6 \
		varnish-4.1.11-1.el6 \
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
	VARNISH_OPTIONS="" \
	VARNISH_STORAGE="file,/var/lib/varnish/varnish_storage.bin,1G" \
	VARNISH_THREAD_TIMEOUT="120" \
	VARNISH_TTL="120" \
	VARNISH_VARNISHNCSA_FORMAT="%h %l %u %t \"%r\" %s %b \"%{Referer}i\" \"%{User-agent}i\"" \
	VARNISH_VARNISHNCSA_OPTIONS="" \
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
	org.deathe.description="CentOS-6 6.10 x86_64 - Varnish Cache 4.1."

HEALTHCHECK \
	--interval=1s \
	--timeout=1s \
	--retries=4 \
	CMD ["/usr/bin/healthcheck"]

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]
