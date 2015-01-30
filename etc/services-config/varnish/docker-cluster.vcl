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
#probe healthcheck_host_2 {
#	.interval = 5s;
#	.timeout = 2s;
#	.window = 5;
#	.threshold = 3;
#	.initial = 2;
#	.expected_response = 200;
#	.request =
#		"GET / HTTP/1.1"
#		"Host: backend-2"
#		"Connection: close"
#		"User-Agent: varnish-probe"
#		"Accept-Encoding: gzip, deflate" ;
#}
#probe healthcheck_host_3 {
#	.interval = 5s;
#	.timeout = 2s;
#	.window = 5;
#	.threshold = 3;
#	.initial = 2;
#	.expected_response = 200;
#	.request =
#		"GET / HTTP/1.1"
#		"Host: backend-3"
#		"Connection: close"
#		"User-Agent: varnish-probe"
#		"Accept-Encoding: gzip, deflate" ;
#}

# -----------------------------------------------------------------------------
# HTTP Backends
# -----------------------------------------------------------------------------
# app-1
backend http_app_1_1_1 { .host = "backend-1"; .port = "8080"; .first_byte_timeout = 300s; .probe = healthcheck; }
backend http_app_1_1_2 { .host = "backend-2"; .port = "8080"; .first_byte_timeout = 300s; .probe = healthcheck; }
backend http_app_1_1_3 { .host = "backend-3"; .port = "8080"; .first_byte_timeout = 300s; .probe = healthcheck; }

# app-2
backend http_app_2_1_1 { .host = "backend-1"; .port = "8081"; .first_byte_timeout = 300s; .probe = healthcheck; }
backend http_app_2_1_2 { .host = "backend-2"; .port = "8081"; .first_byte_timeout = 300s; .probe = healthcheck; }
backend http_app_2_1_3 { .host = "backend-3"; .port = "8081"; .first_byte_timeout = 300s; .probe = healthcheck; }

# -----------------------------------------------------------------------------
# HTTP (HTTPS Terminated) Backends
# -----------------------------------------------------------------------------
# app-1
backend https_app_1_1_1 { .host = "backend-1"; .port = "8580"; .first_byte_timeout = 300s; .probe = healthcheck; }
backend https_app_1_1_2 { .host = "backend-2"; .port = "8580"; .first_byte_timeout = 300s; .probe = healthcheck; }
backend https_app_1_1_3 { .host = "backend-3"; .port = "8580"; .first_byte_timeout = 300s; .probe = healthcheck; }

# app-2
backend https_app_2_1_1 { .host = "backend-1"; .port = "8581"; .first_byte_timeout = 300s; .probe = healthcheck; }
backend https_app_2_1_2 { .host = "backend-2"; .port = "8581"; .first_byte_timeout = 300s; .probe = healthcheck; }
backend https_app_2_1_3 { .host = "backend-3"; .port = "8581"; .first_byte_timeout = 300s; .probe = healthcheck; }

# -----------------------------------------------------------------------------
# Directors
# -----------------------------------------------------------------------------
# app-1
director director_http_app_1 round-robin {
	{ .backend = http_app_1_1_1; }
	{ .backend = http_app_1_1_2; }
	{ .backend = http_app_1_1_3; }
}
director director_https_app_1 round-robin {
	{ .backend = https_app_1_1_1; }
	{ .backend = https_app_1_1_2; }
	{ .backend = https_app_1_1_3; }
}

# app-2
director director_http_app_2 round-robin {
	{ .backend = http_app_2_1_1; }
	{ .backend = http_app_2_1_2; }
	{ .backend = http_app_2_1_3; }
}
director director_https_app_2 round-robin {
	{ .backend = https_app_2_1_1; }
	{ .backend = https_app_2_1_2; }
	{ .backend = https_app_2_1_3; }
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

	# HTTP port range is 8000-8079 and HTTPS offloaded port range is 8500-8579
	# app-n || app-n.local hosts
	if (req.http.host ~ "^app-[0-9]+(\.local)?(:8[05][0-7][0-9])?$") {
		# Make host domain consistent so only cached once: (app-1 -> app-1.local)
		set req.http.host = regsub(req.http.host, "^((app-[0-9]+)(:\d))?", "\2.local\3");

		remove req.http.X-Forwarded-Port;
		set req.http.X-Forwarded-Port = server.port;

		if (server.port == 8443 ||
			server.port == 8500) {
			# Remove the port from host request
#			set req.http.host = regsub(req.http.host, "^([a-zA-Z]+\.)?(app-)([0-9]+)(\.[a-zA-Z]+)?(:\d)?$", "\1\2\3\4");

			# Remove the port from the request URL
#			set req.url = regsub(req.url, "^(\w+://)([^/]+)(:\d)?", "\1\2");

			# Add header to indicate SSL offloaded traffic
			remove req.http.X-Forwarded-Proto;
			set req.http.X-Forwarded-Proto = "https";

			# Set director by host
			if (req.http.host ~ "^app-1.local") {
				set req.backend = director_https_app_1;
			} else if (req.http.host ~ "^app-2.local") {
				set req.backend = director_https_app_2;
			}
		} else {
			# Remove HTTP port from host request
#			set req.http.host = regsub(req.http.host, "^([a-zA-Z]+\.)?(app-)([0-9]+)(\.[a-zA-Z]+)?(:\d)?$", "\1\2\3\4");

			# Set director
			if (req.http.host ~ "^app-1.local") {
				set req.backend = director_http_app_1;
			} else if (req.http.host ~ "^app-2.local") {
				set req.backend = director_http_app_2;
			}
		}
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
	if (req.url ~ "^/admin/.*$" || 
		req.url ~ "^.*/ajax/.*$") {
		return (pass);
	}

	# Cache-Control
	if (req.http.Cache-Control ~ "(private|no-cache|no-store)") {
		return (pass);
	}

	# Allow caching of static files
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