FROM resin/rpi-raspbian:jessie
MAINTAINER Peter Bartlett <p_a_bartlett@yahoo.com.au>

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8

# Default versions
ENV TELEGRAF_VERSION 1.2.0
ENV INFLUXDB_VERSION 1.2.0
ENV GRAFANA_VERSION  4.1.1-1484211277

# Database Defaults
ENV INFLUXDB_GRAFANA_DB datasource
ENV INFLUXDB_GRAFANA_USER datasource
ENV INFLUXDB_GRAFANA_PW datasource

ENV MYSQL_GRAFANA_USER grafana
ENV MYSQL_GRAFANA_PW grafana

# Fix bad proxy issue
COPY system/99fixbadproxy /etc/apt/apt.conf.d/99fixbadproxy

# Clear previous sources
RUN rm -rf /var/lib/apt/lists/*

# Base dependencies
RUN apt-get -y update && \
 apt-get -y dist-upgrade && \
 apt-get -y --force-yes install \
  apt-utils \
  ca-certificates \
  curl \
  git \
  htop \
  libfontconfig \
  mysql-client \
  mysql-server \
  nano \
  net-tools \
  openssh-server \
  supervisor \
  wget && \
 curl -sL https://deb.nodesource.com/setup_7.x | bash - && \
 apt-get install -y nodejs

# Configure Supervisord, SSH and base env
COPY supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

WORKDIR /root

RUN mkdir -p /var/log/supervisor && \
    mkdir -p /var/run/sshd && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    echo 'root:root' | chpasswd && \
    rm -rf .ssh && \
    rm -rf .profile && \
    mkdir .ssh

COPY ssh/id_rsa .ssh/id_rsa
COPY bash/profile .profile

# Configure MySql
COPY scripts/setup_mysql.sh /tmp/setup_mysql.sh

RUN /tmp/setup_mysql.sh

# Install InfluxDB
RUN wget https://dl.influxdata.com/influxdb/releases/influxdb_${INFLUXDB_VERSION}_armhf.deb && \
	dpkg -i influxdb_${INFLUXDB_VERSION}_armhf.deb && rm influxdb_${INFLUXDB_VERSION}_armhf.deb

# Configure InfluxDB
COPY influxdb/influxdb.conf /etc/influxdb/influxdb.conf
COPY influxdb/init.sh /etc/init.d/influxdb

# Install Telegraf
RUN wget https://dl.influxdata.com/telegraf/releases/telegraf_${TELEGRAF_VERSION}_armhf.deb && \
	dpkg -i telegraf_${TELEGRAF_VERSION}_armhf.deb && rm telegraf_${TELEGRAF_VERSION}_armhf.deb

# Configure Telegraf
COPY telegraf/telegraf.conf /etc/telegraf/telegraf.conf
COPY telegraf/init.sh /etc/init.d/telegraf

# Install Grafana
RUN wget https://github.com/fg2it/grafana-on-raspberry/releases/download/v4.4.3/grafana_4.4.3_armhf.deb && \
	dpkg -i grafana_4.4.3_armhf.deb && rm grafana_4.4.3_armhf.deb

# Configure Grafana
COPY grafana/grafana.ini /etc/grafana/grafana.ini

# Cleanup
RUN apt-get clean && \
 rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

CMD ["/usr/bin/supervisord"]
