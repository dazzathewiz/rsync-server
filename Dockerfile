FROM debian:buster

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8
ENV NOTVISIBLE "in users profile"

RUN apt-get update && \
	apt-get install -y openssh-server rsync && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV RSYNC_TIMEOUT 300
ENV RSYNC_MAX_CONNECTIONS 10
ENV RSYNC_PORT 873
ENV SSH_PORT 22
ENV SSH_ENABLE_PASSWORD_LOGIN true
ENV VOL /data

RUN mkdir /var/run/sshd
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN echo "export VISIBLE=now" >> /etc/profile

COPY entrypoint.sh /entrypoint.sh
RUN chmod 744 /entrypoint.sh

EXPOSE ${SSH_PORT}
EXPOSE ${RSYNC_PORT}

CMD ["rsync_server"]
ENTRYPOINT ["/entrypoint.sh"]
