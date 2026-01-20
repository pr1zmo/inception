FROM debian:bookworm

RUN apt-get update && apt-get install\
	vsftpd -y \
	&& rm -Rf /var/lib/apt/lists/*

COPY conf/vsftpd.conf /etc/vsftpd.conf

COPY tools/setup-ftp.sh /usr/local/bin/setup-ftp.sh
RUN chmod +x /usr/local/bin/setup-ftp.sh

RUN mkdir -p /var/run/vsftpd/empty

# Expose FTP ports
# Port 21: FTP control connection
# Ports 21000-21010: Passive mode data connections
EXPOSE 21 21000-21010

ENTRYPOINT [ "/usr/local/bin/setup-ftp.sh" ]