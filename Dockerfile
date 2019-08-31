FROM debian:9
COPY terraform/rtmp-server /tmp/rtmp-server
RUN mkdir -p /var/lib/cloud/instance
RUN touch /var/lib/cloud/instance/boot-finished
RUN cd ~
RUN sed -i "/systemctl disable apt-daily/d" /tmp/rtmp-server/bootstrap.sh
RUN sed -i "/systemctl daemon-reload/d" /tmp/rtmp-server/bootstrap.sh
RUN apt-get -y update && apt-get -y install wget git python procps
RUN git clone https://github.com/gdraheim/docker-systemctl-replacement.git systemctl && cd systemctl && cp file$
RUN bash -x /tmp/rtmp-server/bootstrap.sh test.test.com test@test.com 127.0.0.1 ""
EXPOSE 443
EXPOSE 80
