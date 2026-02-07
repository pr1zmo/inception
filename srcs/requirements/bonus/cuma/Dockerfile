FROM debian:bookworm

RUN apt update && apt install -y \
    git \
    curl \
    npm \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl -sL https://deb.nodesource.com/setup_24.x | bash - && apt install -y nodejs

RUN git clone https://github.com/louislam/uptime-kuma.git .
RUN npm run setup

RUN npm install pm2 -g && pm2 install pm2-logrotate

EXPOSE 3001

CMD ["pm2-runtime", "start", "server/server.js", "--name", "uptime-kuma"]