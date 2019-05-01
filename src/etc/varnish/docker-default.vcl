vcl 4.0;

import directors;
import std;

# ------------------------------------------------------------------------------
# Healthcheck probe (basic)
# ------------------------------------------------------------------------------
probe healthcheck {
	.interval = 5s;
	.timeout = 2s;
	.window = 5;
	.threshold = 3;
	.initial = 2;
	.expected_response = 200;
	.request =
		"GET / HTTP/1.1"
		"Host: localhost.localdomain"
		"Connection: close"
		"User-Agent: Varnish"
		"Accept-Encoding: gzip, deflate";
}

# ------------------------------------------------------------------------------
# Backends
# ------------------------------------------------------------------------------
backend http_1 {
	.host = "httpd_1";
	.port = "80";
	.first_byte_timeout = 300s;
	.probe = healthcheck;
}

backend proxy_1 {
	.host = "httpd_1";
	.port = "8443";
	.first_byte_timeout = 300s;
	.probe = healthcheck;
}

# ------------------------------------------------------------------------------
# Directors
# ------------------------------------------------------------------------------
sub vcl_init {
	new director_http = directors.round_robin();
	director_http.add_backend(http_1);

	new director_proxy = directors.round_robin();
	director_proxy.add_backend(proxy_1);
}

# ------------------------------------------------------------------------------
# Client side
# ------------------------------------------------------------------------------
sub vcl_recv {
	set req.http.X-Cookie = req.http.Cookie;
	unset req.http.Cookie;
	unset req.http.Forwarded;
	unset req.http.Proxy;
	unset req.http.X-Forwarded-Port;
	unset req.http.X-Forwarded-Proto;

	if (std.port(server.ip) == 8443 ||
		std.port(local.ip) == 8443) {
		# Port 8443
		set req.http.X-Forwarded-Port = "443";
		set req.http.X-Forwarded-Proto = "https";
		set req.backend_hint = director_proxy.backend();
	} else if (std.port(server.ip) == 80 ||
		std.port(local.ip) == 80) {
		# Port 80
		set req.http.X-Forwarded-Port = "80";
		set req.backend_hint = director_http.backend();
	} else {
		# Reject unexpected ports
		return (synth(403));
	}

	if (std.healthy(req.backend_hint)) {
		# Cap grace period for healthy backends
		set req.grace = 15s;
	}
}

sub vcl_hash {
	hash_data(req.url);

	if (req.http.Host) {
		hash_data(req.http.Host);
	} else {
		hash_data(server.ip);
	}

	if (req.http.X-Forwarded-Proto) {
		hash_data(req.http.X-Forwarded-Proto);
	}

	if (req.http.X-Cookie) {
		set req.http.Cookie = req.http.X-Cookie;
		unset req.http.X-Cookie;
	}

	return (lookup);
}

sub vcl_hit {
	return (deliver);
}

sub vcl_deliver {
	unset resp.http.Via;
}

# ------------------------------------------------------------------------------
# Backend
# ------------------------------------------------------------------------------
sub vcl_backend_response {
	set beresp.grace = 24h;

	if (bereq.uncacheable) {
		return (deliver);
	} else if (beresp.ttl <= 0s ||
		beresp.http.Set-Cookie ||
		beresp.http.Surrogate-Control ~ "^(?i)no-store$" ||
		( ! beresp.http.Surrogate-Control &&
			beresp.http.Cache-Control ~ "^(?i:private|no-cache|no-store)$") ||
		beresp.http.Vary == "*") {
		# Mark as "hit-for-miss" for 2 minutes
		set beresp.ttl = 120s;
		set beresp.uncacheable = true;
	}

	return (deliver);
}
