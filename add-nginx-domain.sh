#!/bin/bash

# download and run this script with the following command:
# [email] is your email
# [domain] is the domain you want to add
# [port] is the port you want to use locally for your domain    
# curl -sSL https://raw.githubusercontent.com/frani/tools/main/add-nginx-domain.sh | sudo bash -s [email] [domain] [port]

# Check if the user is root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Check if nginx, certbot and python3-certbot-nginx are installed, if not install them
if ! [ -x "$(command -v nginx)" ]; then
    echo "Nginx is not installed."
    echo "Installing Nginx"
    apt update
    apt install nginx
fi

if ! [ -x "$(command -v certbot)" ]; then
    echo "Certbot is not installed."
    echo "Installing Certbot"
    apt update
    apt install certbot 
fi

if ! [ -x "$(command -v python3-certbot-nginx)" ]; then
    echo "Python3-certbot-nginx is not installed."
    echo "Installing Python3-certbot-nginx"
    apt update
    apt install python3-certbot-nginx
fi

# Check if the user has passed the correct number of arguments
if [ $# -ne 3 ]; then
    echo "Usage: $0 email domain port"
    exit 1
fi

# Check if the domain is already in the config file
if [ -f "/etc/nginx/sites-available/$domain" ]; then
    echo "The domain $domain is already in the config file."
    exit 1
fi

email="$1"
domain="$2"
port="$3"

# Configuration file name
config_file="/etc/nginx/sites-available/$domain"

# Check if the file already exists
if [ -f "$config_file" ]; then
    echo "The configuration file $config_file already exists."
    exit 1
fi

# if nginx is running, stop it
if [ "$(systemctl is-active nginx)" = "active" ]; then
    systemctl stop nginx
fi

# Get the SSL certificate for the domain using certbot nginx silently
certbot certonly --nginx --preferred-challenges http -d $domain --non-interactive --agree-tos --email $email

# Create the configuration file
cat > "$config_file" <<EOF
server {
    server_name $domain;

    location / {
        proxy_pass http://localhost:$port;
        include /etc/nginx/proxy_params;
    }

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}

server {
    if (\$host = $domain) {
        return 301 https://\$host\$request_uri;
    } # managed by Certbot

    listen 80;
    server_name $domain;
    return 404; # managed by Certbot
}
EOF

ln -s $config_file /etc/nginx/sites-enabled/

echo "The configuration file $config_file has been created successfully in sites-available."

echo "Restarting Nginx"

service nginx restart

service nginx status
