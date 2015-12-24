# =============================================================================
# jdeathe/centos-ssh-varnish
#
# CentOS-6, Varnish 3.0
#
# BUILD: 
#	docker build -t jdeathe/centos-ssh-varnish .
# RUN:
#	docker run -d --privileged --name varnish.pool-1.1.1 \
#		-p 8000:80 -p 8500:8443 \
#		jdeathe/centos-ssh-varnish:latest
# ACCESS:
#   docker exec -it varnish.pool-1.1.1 bash
# ALTERNATIVE ACCESS:
#	sudo /usr/bin/nsenter -m -u -i -n -p -t $(/usr/bin/docker inspect \
#		--format '{{ .State.Pid }}' varnish.pool-1.1.1) /bin/bash
# =============================================================================
FROM jdeathe/centos-ssh:centos-6-1.4.0

MAINTAINER James Deathe <james.deathe@gmail.com>

# -----------------------------------------------------------------------------
# Install Varnish Cache
# -----------------------------------------------------------------------------
RUN rpm --nosignature -Uvh http://repo.varnish-cache.org/redhat/varnish-3.0/el6/noarch/varnish-release/varnish-release-3.0-1.el6.noarch.rpm \
	&& yum --setopt=tsflags=nodocs -y install \
	varnish \
	&& rm -rf /var/cache/yum/* \
	&& yum clean all

# -----------------------------------------------------------------------------
# Copy files into place
# -----------------------------------------------------------------------------
ADD etc/varnish-start /etc/
ADD etc/services-config/supervisor/supervisord.conf /etc/services-config/supervisor/
ADD etc/services-config/varnish/docker-default.vcl /etc/services-config/varnish/

RUN ln -sf /etc/services-config/supervisor/supervisord.conf /etc/supervisord.conf \
	&& ln -sf /etc/services-config/varnish/docker-default.vcl /etc/varnish/docker-default.vcl \
	&& chmod +x /etc/varnish-start \
	&& chmod 644 /etc/varnish/*.vcl

EXPOSE 80 8443

# -----------------------------------------------------------------------------
# Set default environment variables
# -----------------------------------------------------------------------------
ENV MEMLOCK 82000
ENV NFILES 131072
ENV NPROCS "unlimited"
ENV VARNISH_ADMIN_LISTEN_ADDRESS 127.0.0.1
ENV VARNISH_ADMIN_LISTEN_PORT 6082
ENV VARNISH_LISTEN_ADDRESS 0.0.0.0
ENV VARNISH_LISTEN_PORT 80,0.0.0.0:8443
ENV VARNISH_MAX_THREADS 1000
ENV VARNISH_MIN_THREADS 50
ENV VARNISH_PIDFILE /var/run/varnish.pid
ENV VARNISH_SECRET_FILE /etc/varnish/secret
ENV VARNISH_STORAGE file,/var/lib/varnish/varnish_storage.bin,1G
ENV VARNISH_THREAD_TIMEOUT 120
ENV VARNISH_TTL 120
ENV VARNISH_VCL_CONF /etc/varnish/docker-default.vcl

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]