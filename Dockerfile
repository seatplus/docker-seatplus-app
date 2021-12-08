FROM php:8.0-fpm-alpine as seat-plus

RUN apk add --no-cache \
    # Install OS level dependencies
    git zip unzip curl \
    libpng-dev libmcrypt-dev bzip2-dev icu-dev mariadb-client && \
    # Install PHP dependencies
    docker-php-ext-install pdo_mysql gd bz2 intl pcntl

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin \
    --filename=composer && hash -r

# Install Node and NPM
RUN apk add --update nodejs npm

# Install PHP Redis
ENV PHPREDIS_VERSION 5.3.4
RUN mkdir -p /usr/src/php/ext/redis \
    && curl -L https://github.com/phpredis/phpredis/archive/$PHPREDIS_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/redis --strip 1 \
    && echo 'redis' >> /usr/src/php-available-exts \
    && docker-php-ext-install redis

RUN mkdir -p /usr/src && cd /usr/src && \
    # Install seatplus
    composer create-project seatplus/core --no-scripts --prefer-dist --no-dev --no-ansi --no-progress && \
    # Cleanup composer caches
    composer clear-cache --no-ansi

RUN cd /usr/src/core && \
    php artisan vendor:publish --tag=web --force && \
    php artisan vendor:publish --tag=horizon-config --force && \
    php artisan vendor:publish --tag=horizon-assets --force && \
    php artisan vendor:publish --tag=horizon-provider --force && \
     # Fix up the source permissions to be owned by www-data
    chown -R www-data:www-data /usr/src/core/

COPY startup.sh /root/startup.sh
RUN chmod +x /root/startup.sh

#RUN chown -R www-data:www-data storage

# Change volume and workdir
WORKDIR /var/www

#
CMD ["php-fpm", "-F"]
#
ENTRYPOINT ["/bin/sh", "/root/startup.sh"]