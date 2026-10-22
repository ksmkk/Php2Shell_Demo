FROM php:8.4.26-apache

COPY config/php/lab.ini /usr/local/etc/php/conf.d/zz-ucn-lab.ini
COPY config/apache/lab.conf /etc/apache2/conf-enabled/zz-ucn-lab.conf
COPY app/public/ /var/www/html/

RUN chown -R root:root /var/www/html \
    && find /var/www/html -type d -exec chmod 0755 {} + \
    && find /var/www/html -type f -exec chmod 0644 {} +

