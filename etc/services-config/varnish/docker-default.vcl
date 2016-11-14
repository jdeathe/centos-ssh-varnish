# -----------------------------------------------------------------------------
# Note:
# Backend hosts entries or DNS configuration is required to map the backend-1, 
# backend-2, backend-n hostnames to the backend host IP addresses.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Healthcheck probe (basic)
# -----------------------------------------------------------------------------
probe healthcheck {
	.interval = 5s;
	.timeout = 2s;
	.window = 5;
	.threshold = 3;
	.initial = 2;
	.expected_response = 200;
	.url = "/";
}

# -----------------------------------------------------------------------------
# Healthcheck probe (advanced)
# -----------------------------------------------------------------------------
#probe healthcheck_host_1 {
#	.interval = 5s;
#	.timeout = 2s;
#	.window = 5;
#	.threshold = 3;
#	.initial = 2;
#	.expected_response = 200;
#	.request =
#		"GET / HTTP/1.1"
#		"Host: backend-1"
#		"Connection: close"
#		"User-Agent: varnish-probe"
#		"Accept-Encoding: gzip, deflate" ;
#}

# -----------------------------------------------------------------------------
# HTTP Backends
# -----------------------------------------------------------------------------
backend http_1 { .host = "backend-1"; .port = "80"; .first_byte_timeout = 300s; .probe = healthcheck; }

# -----------------------------------------------------------------------------
# HTTPS Backends
# -----------------------------------------------------------------------------
backend https_1 { .host = "backend-1"; .port = "443"; .first_byte_timeout = 300s; .probe = healthcheck; }

# -----------------------------------------------------------------------------
# HTTP (HTTPS Terminated) Backends
# -----------------------------------------------------------------------------
backend terminated_https_1 { .host = "backend-1"; .port = "8443"; .first_byte_timeout = 300s; .probe = healthcheck; }


# -----------------------------------------------------------------------------
# Directors
# -----------------------------------------------------------------------------
director director_http round-robin {
	{ .backend = http_1; }
}
director director_https round-robin {
	{ .backend = https_1; }
}
director director_terminated_https round-robin {
	{ .backend = terminated_https_1; }
}

# -----------------------------------------------------------------------------
# VCL logic
# -----------------------------------------------------------------------------
sub vcl_recv {
	# Allow stale objects to be served if necessary
	if (! req.backend.healthy) {
		set req.grace = 1h;
	} else {
		set req.grace = 15s;
	}

	if (req.http.x-forwarded-for) {
		set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
	} else {
		set req.http.X-Forwarded-For = client.ip;
	}

	if (server.port == 8443) {
		# SSL Terminated upstream so indcate this with a custom header
		remove req.http.X-Forwarded-Proto;
		set req.http.X-Forwarded-Proto = "https";
		set req.backend = director_terminated_https;
	} else if (server.port == 443) {
		# HTTPS
		set req.backend = director_https;
	} else {
		# Default to HTTP
		set req.backend = director_http;
	}

	# Non-RFC2616 or CONNECT which is weird.
	if (req.request != "GET" &&
		req.request != "HEAD" &&
		req.request != "PUT" &&
		req.request != "POST" &&
		req.request != "TRACE" &&
		req.request != "OPTIONS" &&
		req.request != "DELETE") {
		return (pipe);
	}

	# Only deal with GET and HEAD by default
	if (req.request != "GET" && 
		req.request != "HEAD") {
		return (pass);
	}

	# Handle Expect request
	if (req.http.Expect) {
		return (pipe);
	}

	# Never cache these paths.
	# if (req.url ~ "^/admin/.*$" || 
	# 	req.url ~ "^.*/ajax/.*$") {
	# 	return (pass);
	# }

	# Cache-Control
	if (req.http.Cache-Control ~ "(private|no-cache|no-store)") {
		return (pass);
	}

	# Cache static assets
	if (req.url ~ "\.(gif|png|jpe?g|ico|swf|css|js|html?|txt)$") {
		unset req.http.Cookie;
		return (lookup);
	}

	# Remove all cookies that we doesn't need to know about. e.g. 3rd party analytics cookies
	if (req.http.Cookie) {
		set req.http.Cookie = ";" + req.http.Cookie;
		set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
		set req.http.Cookie = regsuball(req.http.Cookie, ";(PHPSESSID|app-session)=", "; \1=");
		set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
		set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

		if (req.http.Cookie == "") {
			unset req.http.Cookie;
		}
	}

	# Non-cacheable requests
	if (req.http.Authorization || 
		req.http.Cookie) {
		return (pass);
	}

	return (lookup);
}

sub vcl_fetch {
	# Keep objects beyond their ttl
	set beresp.grace = 6h;

	if (beresp.ttl <= 0s ||
		beresp.http.Set-Cookie ||
		beresp.http.Vary == "*") {
		# Mark as "Hit-For-Pass" for the next 2 minutes
		set beresp.ttl = 120s;
		return (hit_for_pass);
	}

	return (deliver);
}