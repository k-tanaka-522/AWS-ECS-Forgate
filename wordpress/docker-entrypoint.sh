#!/bin/bash
set -euo pipefail

# Activate Cognito plugin and configure it
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

# Execute original entrypoint
exec docker-entrypoint.sh "$@"
