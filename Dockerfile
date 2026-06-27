FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY sites/ /var/www/

EXPOSE 80 443
