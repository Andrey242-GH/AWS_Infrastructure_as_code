FROM php:7.2-apache
COPY index.php /var/www/html/

docker build -t my-php-app .
docker run -d  --name myRunningApp -p 8080:80 my-php-app

