FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY sites/portfolio-elias /var/www/portfolio-elias
COPY sites/ofipro-fronted /var/www/ofipro-fronted

EXPOSE 80 
