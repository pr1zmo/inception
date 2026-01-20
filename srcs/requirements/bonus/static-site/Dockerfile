FROM debian:bookworm

RUN apt-get update && apt-get install -y curl\
	&& curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
	&& apt-get install -y nodejs \
	&& rm -Rf /var/lib/apt/lists/*

WORKDIR /usr/app

RUN mkdir -p /usr/app/public

COPY tools/package.json .

RUN npm install

COPY srcs/index.html public/.
COPY srcs/style.css public/.
COPY tools/server.js .

CMD ["node", "server.js"]