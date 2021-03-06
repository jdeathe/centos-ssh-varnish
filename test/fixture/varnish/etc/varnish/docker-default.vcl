vcl 4.0;

import directors;
import std;

# ------------------------------------------------------------------------------
# Healthcheck probe (basic)
# ------------------------------------------------------------------------------
probe healthcheck {
	.interval = 5s;
	.timeout = 2s;
	.window = 3;
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
	if (req.http.Cookie != "") {
		set req.http.X-Cookie = req.http.Cookie;
	}
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
		set req.http.X-Forwarded-Proto = "http";
		set req.backend_hint = director_http.backend();
	} else {
		# Reject unexpected ports
		return (synth(403));
	}

	# Handle monitoring status endpoints /status and /varnish-status
	if (req.url ~ "(?i)^/status(\?.*)?$" &&
		!std.healthy(req.backend_hint)) {
		return (synth(503, "Service Unavailable"));
	} else if (req.url ~ "(?i)^/(varnish-)?status(\?.*)?$") {
		return (synth(200, "OK"));
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
	}
	unset req.http.X-Cookie;

	return (lookup);
}

sub vcl_hit {
	return (deliver);
}

sub vcl_deliver {
	unset resp.http.Via;

	if (resp.status >= 400) {
		return (synth(resp.status));
	}
}

sub vcl_synth {
	set resp.http.Content-Type = "text/html; charset=utf-8";
	set resp.http.Retry-After = "5";
	set resp.http.X-Frame-Options = "DENY";
	set resp.http.X-XSS-Protection = "1; mode=block";

	if (req.url ~ "(?i)\.(css|eot|gif|ico|jpe?g|js|png|svg|ttf|txt|woff2?)(\?.*)?$") {
		# Respond with simple text error for static assets.
		set resp.body = resp.status + " " + resp.reason;
		set resp.http.Content-Type = "text/plain; charset=utf-8";
	} else if (req.url ~ "(?i)^/(varnish-)?status(\.php)?(\?.*)?$") {
		# Respond with simple text error for status uri.
		set resp.body = resp.reason;
		set resp.http.Cache-Control = "no-store";
		set resp.http.Content-Type = "text/plain; charset=utf-8";
	} else if (resp.status < 500) {
		set resp.body = {"<!DOCTYPE html>
<html>
	<head>
		<title>"} + resp.reason + {"</title>
		<style>
			body{color:#666;background-color:#f1f1f1;font-family:sans-serif;margin:12%;max-width:50%;}
			h1,h2{color:#333;font-size:4rem;font-weight:400;text-transform:uppercase;}
			h2{color:#333;font-size:2rem;}
			p{font-size:1.5rem;}
		</style>
	</head>
	<body>
		<h1>"} + resp.status + {"</h1>
		<h2>"} + resp.reason + {"</h2>
	</body>
</html>"};
	} else {
		set resp.body = {"<!DOCTYPE html>
<html>
	<head>
		<title>"} + resp.reason + {"</title>
		<style>
			body{color:#666;background-color:#f1f1f1;font-family:sans-serif;margin:12%;max-width:50%;}
			h1,h2{color:#333;font-size:4rem;font-weight:400;text-transform:uppercase;}
			h2{color:#333;font-size:2rem;}
			p{font-size:1.5rem;}
		</style>
	</head>
	<body>
		<h1>"} + resp.status + {"</h1>
		<h2>"} + resp.reason + {"</h2>
		<p>XID: "} + req.xid + {"</p>
	</body>
</html>"};
	}

	return (deliver);
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
		beresp.http.Surrogate-Control ~ "(?i)^no-store$" ||
		( ! beresp.http.Surrogate-Control &&
			beresp.http.Cache-Control ~ "(?i)^(private|no-cache|no-store)$") ||
		beresp.http.Vary == "*") {
		# Mark as "hit-for-miss" for 2 minutes
		set beresp.ttl = 120s;
		set beresp.uncacheable = true;
	}

	return (deliver);
}

sub vcl_backend_error {
	set beresp.http.Content-Type = "text/html; charset=utf-8";
	set beresp.http.Retry-After = "5";
	set beresp.http.X-Frame-Options = "DENY";
	set beresp.http.X-XSS-Protection = "1; mode=block";

	if (bereq.url ~ "(?i)\.(css|eot|gif|ico|jpe?g|js|png|svg|ttf|txt|woff2?)(\?.*)?$") {
		# Respond with simple text error for static assets.
		set beresp.body = beresp.status + " " + beresp.reason;
		set beresp.http.Content-Type = "text/plain; charset=utf-8";
	} else if (bereq.url ~ "(?i)^/(varnish-)?status(\.php)?(\?.*)?$") {
		# Respond with simple text error for status uri.
		set beresp.body = beresp.reason;
		set beresp.http.Cache-Control = "no-store";
		set beresp.http.Content-Type = "text/plain; charset=utf-8";
	} else {
		set beresp.body = {"<!DOCTYPE html>
<html>
	<head>
		<title>"} + beresp.reason + {"</title>
		<style>
			body{color:#666;background-color:#f1f1f1;font-family:sans-serif;margin:12%;max-width:50%;}
			h1,h2{color:#333;font-size:4rem;font-weight:400;text-transform:uppercase;}
			h2{color:#333;font-size:2rem;}
			p{font-size:1.5rem;}
		</style>
	</head>
	<body>
		<h1>"} + beresp.status + {"</h1>
		<h2>"} + beresp.reason + {"</h2>
		<p>XID: "} + bereq.xid + {"</p>
	</body>
</html>"};
	}

	return (deliver);
}
