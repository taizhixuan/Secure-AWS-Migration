# MMU Student Information System — production container image.
# Base: official PHP 8.2 with Apache (a maintained, regularly-patched image).
FROM php:8.2-apache

# MySQL PDO driver + Apache modules used for security headers / clean URLs.
RUN docker-php-ext-install pdo_mysql \
 && a2enmod headers rewrite

# Serve from public/ only, so application source in src/ and db/ is never
# web-accessible. (Pattern from the official PHP image documentation.)
ENV APACHE_DOCUMENT_ROOT=/var/www/app/public
RUN sed -ri "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/sites-available/*.conf \
 && sed -ri "s!/var/www/!/var/www/app/!g" /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Baseline hardening: security headers, no version banners, no directory listing.
RUN printf '%s\n' \
    'ServerTokens Prod' \
    'ServerSignature Off' \
    'Header always set X-Content-Type-Options "nosniff"' \
    'Header always set X-Frame-Options "DENY"' \
    'Header always set Referrer-Policy "strict-origin-when-cross-origin"' \
    '<Directory /var/www/app/public>' \
    '  Options -Indexes +FollowSymLinks' \
    '  AllowOverride None' \
    '  Require all granted' \
    '</Directory>' \
    > /etc/apache2/conf-available/zzz-hardening.conf \
 && a2enconf zzz-hardening

# PHP production settings: never leak errors to users, log them instead.
RUN { \
      echo 'display_errors=Off'; \
      echo 'log_errors=On'; \
      echo 'expose_php=Off'; \
      echo 'session.cookie_httponly=On'; \
      echo 'session.cookie_samesite=Strict'; \
    } > /usr/local/etc/php/conf.d/zz-hardening.ini

# Application code.
COPY . /var/www/app
RUN chown -R www-data:www-data /var/www/app

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD php -r '$c=@fsockopen("127.0.0.1",80);exit($c?0:1);' || exit 1

EXPOSE 80
