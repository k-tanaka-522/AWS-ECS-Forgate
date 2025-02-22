#!/bin/bash
set -euo pipefail

# Ensure correct permissions
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Ensure WordPress directory is properly set up
cd /var/www/html

# Start Apache in background
/usr/sbin/httpd

# Wait for Apache to start and ensure WordPress files are accessible
sleep 5

# Install and activate Cognito plugin
cd /var/www/html/wp-content/plugins
if [ ! -d "aws-cognito-wp-auth" ]; then
    # Try official WordPress plugin repository first
    wp plugin install aws-cognito-wp-auth --allow-root || {
        echo "Plugin not found in WordPress repository, installing from GitHub..."
        git clone https://github.com/humanmade/aws-cognito-wp-auth.git || {
            echo "Failed to install plugin from GitHub"
            exit 1
        }
    }
fi

wp plugin activate aws-cognito-wp-auth --allow-root

# Configure Cognito settings if environment variables are provided
if [ ! -z "${COGNITO_USER_POOL_ID:-}" ] && [ ! -z "${COGNITO_CLIENT_ID:-}" ]; then
    wp option update aws_cognito_wp_auth_user_pool_id "$COGNITO_USER_POOL_ID" --allow-root
    wp option update aws_cognito_wp_auth_client_id "$COGNITO_CLIENT_ID" --allow-root
    wp option update aws_cognito_wp_auth_region "ap-northeast-1" --allow-root
fi

# Install and activate required theme
wp theme install twentytwentythree --activate --allow-root

# Create default pages if they don't exist
wp post create --post_type=page --post_title='Home' --post_status='publish' --allow-root
wp post create --post_type=page --post_title='About' --post_status='publish' --allow-root

# Update site settings
wp option update blogname "ESCForgate WordPress" --allow-root
wp option update blogdescription "Powered by ECS & Cognito" --allow-root

# Stop Apache
/usr/sbin/httpd -k stop

# Start Apache in foreground
exec "$@"
