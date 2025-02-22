FROM wordpress:latest

# Install required PHP extensions and utilities
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    git \
    unzip \
    && docker-php-ext-install soap \
    && rm -rf /var/lib/apt/lists/*

# Install AWS SDK for PHP
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer require aws/aws-sdk-php

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Copy custom wp-config.php
COPY wp-config.php /var/www/html/wp-config.php

# Copy Cognito authentication plugin
WORKDIR /var/www/html/wp-content/plugins
RUN git clone https://github.com/humanmade/aws-cognito-wp-auth.git

# Set permissions
RUN chown -R www-data:www-data /var/www/html

# Return to default work directory
WORKDIR /var/www/html

# Add custom entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
