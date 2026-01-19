FROM debian:bookworm

RUN mkdir -p /var/www/portfolio

COPY ./srcs/index.html /var/www/portfolio/index.html
COPY ./srcs/style.css /var/www/portfolio/style.css

RUN chown -R www-data:www-data /var/www/portfolio

CMD ["tail", "-f"]