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

echo "Performing permissions fixups"
chown -R www-data:www-data .
find . -type d -print0 | xargs -0 chmod 775
find . -type f -print0 | xargs -0 chmod 664

# compile js-files
npm install && npm run development

echo "Done. Starting php-fpm"
php-fpm -F

