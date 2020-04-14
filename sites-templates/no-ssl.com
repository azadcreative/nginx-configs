server {
	# Ports to listen on
	listen 80;
	listen [::]:80;

	# Server name to listen for
	server_name no-ssl.com;

	# Path to document root
	root /var/www/html/no-ssl.com/web;

	# File to be used as index
	index index.php;

	# Server Block Rules
	include conf.d/server/fastcgi-cache.conf;
	include conf.d/server/cache-expires.conf;
	include conf.d/server/exclusions.conf;
	include conf.d/server/wordpress-security.conf;
	include conf.d/server/wordpress-cache.conf;

	# Overrides logs defined in nginx.conf, allows per site logs.
	access_log /var/www/logs/no-ssl.com/access.log;
	error_log /var/www/logs/no-ssl.com/error.log;
	
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
}

# Redirect www to non-www
server {
	listen 80;
	listen [::]:80;
	server_name www.no-ssl.com;

	return 301 $scheme://no-ssl.com$request_uri;
}
