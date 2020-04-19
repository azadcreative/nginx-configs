server {
	# Ports to listen on, uncomment one.
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	# Server name to listen for
	server_name ssl.com;

	# Path to document root
	root /var/www/html/ssl.com/web;

	# File to be used as index
	index index.php;

	# Server Block Rules
	include conf.d/server/fastcgi-cache.conf;
	include conf.d/server/cache-expires.conf;
	include conf.d/server/exclusions.conf;

	# Overrides logs defined in nginx.conf, allows per site logs.
	access_log /var/www/logs/ssl.com/access.log;
	error_log /var/www/logs/ssl.com/error.log;
	
	# Customize what Nginx returns to the client in case of an error.
	# https://nginx.org/en/docs/http/ngx_http_core_module.html#error_page
	error_page 404 /404.html;
	error_page 500 /500.html;

	location / {
		try_files $uri $uri/ /index.php?$args;
	}

	location ~ \.php$ {
		try_files $uri =404;
		include global/fastcgi-params.conf;

		# Use the php pool defined in the upstream variable.
		# See global/php-pool.conf for definition.
		fastcgi_pass   $upstream;
	}

	# Rewrite robots.txt
	rewrite ^/robots.txt$ /index.php last;
	
	# Paths to SSL Certificate files.
	#
	ssl_certificate /path/to/certificate.crt;
	ssl_certificate_key /path/to/key.key;
	#ssl_trusted_certificate /path/to/ca.crt;
	#ssl_client_certificate /etc/nginx/default_ssl.crt;

	# SSL Policies
	#
	include conf.d/ssl/ssl-engine.conf; # DISABLE if using LetsEncrypt Certbot
	include conf.d/ssl/policy-modern.conf; # DISABLE if using LetsEncrypt Certbot
	#include conf.d/ssl/ocsp-stapling.conf; # Use ONLY if ssl_trusted_certificate present
	#ssl_dhparam /etc/ssl/ssl-dhparams.pem; # DISABLE if using LetsEncrypt Certbot. Generate before use.

}

# Redirect http to https
server {
	listen 80;
	listen [::]:80;
	server_name ssl.com www.ssl.com;

	return 301 https://ssl.com$request_uri;
}

# Redirect www to non-www
server {
	listen 443;
	listen [::]:443;
	server_name www.ssl.com;

	return 301 https://ssl.com$request_uri;
}
