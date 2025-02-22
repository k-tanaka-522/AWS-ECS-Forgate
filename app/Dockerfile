FROM amazonlinux:2023

# Install Apache, PHP, curl and required extensions
RUN dnf update -y && \
    dnf install -y httpd php php-mysqlnd php-soap php-xml php-gd php-intl php-mbstring php-json unzip git tar && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install AWS SDK for PHP
RUN composer require aws/aws-sdk-php

# Download and install WordPress
RUN curl -O https://wordpress.org/latest.tar.gz && \
    tar -xzf latest.tar.gz && \
    mv wordpress/* /var/www/html/ && \
    rm -rf wordpress latest.tar.gz

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Copy custom wp-config.php
COPY wp-config.php /var/www/html/wp-config.php

# Create plugins directory
WORKDIR /var/www/html/wp-content/plugins

# Set permissions
RUN chown -R apache:apache /var/www/html

# Configure Apache
RUN sed -i 's/Listen 80/Listen 3000/' /etc/httpd/conf/httpd.conf && \
    sed -i 's/User apache/User www-data/' /etc/httpd/conf/httpd.conf && \
    sed -i 's/Group apache/Group www-data/' /etc/httpd/conf/httpd.conf

# Create www-data user and group
RUN groupadd www-data && \
    useradd -r -g www-data www-data

# Return to default work directory
WORKDIR /var/www/html

# Add custom entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
