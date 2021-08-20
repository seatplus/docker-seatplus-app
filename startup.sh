#!/bin/sh
set -e

# Ensure the latest sources from this container lives in the volume.
# Working dir is /var/www from the container.
find . -maxdepth 1 ! -name . -exec rm -r {} \; && \
   tar cf - --one-file-system -C /usr/src/core . | tar xf -

# Wait for the database
while ! mysqladmin ping --host=${DB_HOST} --user=${DB_USERNAME} --password=${DB_PASSWORD} --silent; do

    echo "MariaDB container might not be ready yet... sleeping..."
    sleep 10
done

# Create an .env if needed
php -r "file_exists('.env') || copy('.env.example', '.env');"

# Run migrations (--force is needed as the app is running in prod)
php artisan migrate --force

# Plugin support. The docker-compose.yml has the option
# for setting SEATPLUS_PLUGINS environment variable. Read
# that here and split by commas.
echo "Installing and updating plugins..."
plugins=`echo -n ${SEATPLUS_PLUGINS} | sed 's/,/ /g'`

# If we have any plugins to process, do that.
if [ ! "$plugins" == "" ]; then

    echo "Installing plugins: ${SEATPLUS_PLUGINS}"

    # Why are we doing it like this?
    #   ref: https://github.com/composer/composer/issues/1874

    # Require the plugins from the environment variable.
    composer require ${plugins} --update-no-dev

    # Publish assets and migrations and run them.
    php artisan migrate --force
    php artisan vendor:publish --tag=web --force
fi

echo "Completed plugins processing"

echo "Performing permissions fixups"
chown -R www-data:www-data .
find . -type d -print0 | xargs -0 chmod 775
find . -type f -print0 | xargs -0 chmod 664

# compile js-files
npm install && npm run prod

echo "Done. Starting php-fpm"
php-fpm -F

