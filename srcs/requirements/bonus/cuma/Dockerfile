FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    git \
    nodejs \
    npm \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN git clone https://github.com/louislam/uptime-kuma.git .
RUN npm run setup

RUN npm install pm2 -g && pm2 install pm2-logrotate

EXPOSE 3001

CMD ["pm2-runtime", "start", "server/server.js", "--name", "uptime-kuma"]