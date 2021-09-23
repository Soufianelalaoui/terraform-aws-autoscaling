#!/usr/bin/bash

# Install Nginx
sudo amazon-linux-extras install -y nginx1
sudo systemctl enable nginx

# Install Client Website
rm -rf /usr/share/nginx/html/*
curl -L  https://github.com/Lowess/restaurant-landingpage/archive/v1.0.0.tar.gz --output web.tar.gz
tar xzf web.tar.gz --strip 1 -C /usr/share/nginx/html

# Configure Nginx
cat <<EOF > /etc/nginx/nginx.conf
### Nginx Conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;


include /usr/share/nginx/modules/*.conf;

events {
worker_connections 1024;
}

http {
log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    '$status $body_bytes_sent "$http_referer" '
    '"$http_user_agent" "$http_x_forwarded_for"';

access_log  /var/log/nginx/access.log  main;

sendfile            on;
tcp_nopush          on;
tcp_nodelay         on;
keepalive_timeout   65;
types_hash_max_size 4096;

include             /etc/nginx/mime.types;
default_type        application/octet-stream;

# Load modular configuration files from the /etc/nginx/conf.d directory.
# See http://nginx.org/en/docs/ngx_core_module.html#include
# for more information.
include /etc/nginx/conf.d/*.conf;

server {
listen 8080;
server_name  _;
root         /usr/share/nginx/html;

# Load configuration files for the default server block.
include /etc/nginx/default.d/*.conf;

error_page 404 /404.html;
location = /404.html {
}

error_page 500 502 503 504 /50x.html;
location = /50x.html {
}
}
}
EOF

sudo systemctl restart nginx