########################################################################
# Dockerfile for Statsd, Graphite, Grafana on ubuntu 14.04
#
#                    ##        .
#              ## ## ##       ==
#           ## ## ## ##      ===
#       /""""""""""""""""\___/ ===
#  ~~~ {~~ ~~~~ ~~~ ~~~~ ~~ ~ /  ===- ~~~
#       \______ o          __/
#         \    \        __/
#          \____\______/
#
# Component:    StatsD (0.7.1), Carbon, Graphite, Grafana
# Author:       pjan vandaele <pjan@pjan.io>
# Scm url:      https://github.com/pjan/docker-monitor
# License:      MIT
########################################################################

# pull base image
FROM ubuntu:14.04

# maintainer details
MAINTAINER pjan vandaele "pjan@pjan.io"

# add a post-invoke hook to dpkg which deletes cached deb files
# update the sources.list
# update/dist-upgrade
# clear the caches
RUN \
  echo 'DPkg::Post-Invoke {"/bin/rm -f /var/cache/apt/archives/*.deb || true";};' | tee /etc/apt/apt.conf.d/no-cache && \
  echo "deb http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu trusty main universe" >> /etc/apt/sources.list && \
  apt-get update -q -y && \
  apt-get dist-upgrade -y && \
  apt-get clean && \
  rm -rf /var/cache/apt/*

RUN \
  apt-get install -y wget git


# -------------------- #
#     Installation     #
# -------------------- #

# Install StatsD
RUN \
  DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common python-software-properties && \
  add-apt-repository -y ppa:chris-lea/node.js && \
  apt-get update -q && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs && \
  git clone https://github.com/etsy/statsd.git /opt/statsd && \
  cd /opt/statsd && \
  git checkout v0.7.1 && \
  cd /


# install carbon & graphite
RUN \
  DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential python-dev python-support python-pip python-cairo python-pysqlite2 python-ldap python-simplejson && \
  pip install Twisted==14.0.0 Django==1.5 django-tagging python-memcached gunicorn whisper && \
  pip install --install-option="--prefix=/opt/graphite" --install-option="--install-lib=/opt/graphite/lib" carbon && \
  pip install --install-option="--prefix=/opt/graphite" --install-option="--install-lib=/opt/graphite/webapp" graphite-web && \
  ln -s /opt/graphite/conf /etc/graphite && \
  sed -i '/from twisted.scripts._twistd_unix import daemonize/d' /opt/graphite/lib/carbon/util.py && \
  sed -i '/daemonize = daemonize  # Backwards compatibility/d' /opt/graphite/lib/carbon/util.py

# install grafana
RUN \
  mkdir /opt/grafana && cd /opt/grafana && \
  wget http://grafanarel.s3.amazonaws.com/grafana-1.7.0.tar.gz && \
  tar xzvf grafana-1.7.0.tar.gz --strip-components=1 && rm grafana-1.7.0.tar.gz && \
  cd /

# install elasticsearch
RUN \
  DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common python-software-properties && \
  add-apt-repository -y ppa:webupd8team/java && \
  apt-get update -q && \
  echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y oracle-java7-installer && \
  cd / && wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.3.2.deb && \
  dpkg -i elasticsearch-1.3.2.deb && rm elasticsearch-1.3.2.deb && \
  chown -R elasticsearch:elasticsearch /var/lib/elasticsearch && \
  mkdir -p /tmp/elasticsearch && chown elasticsearch:elasticsearch /tmp/elasticsearch

# install nginx
RUN \
  DEBIAN_FRONTEND=noninteractive apt-get install -y nginx

# install supervisord
RUN \
  DEBIAN_FRONTEND=noninteractive apt-get install -y supervisor


# --------------------- #
#     Configuration     #
# --------------------- #

# Configure StatsD
ADD     ./config/opt_statsd_config.js /opt/statsd/config.js

# Configure carbon & graphite
ADD     ./config/opt_graphite_conf_carbon.conf /opt/graphite/conf/carbon.conf
ADD     ./config/opt_graphite_conf_storage-aggregation.conf /opt/graphite/conf/storage-aggregation.conf
ADD     ./config/opt_graphite_conf_storage-schemas.conf /opt/graphite/conf/storage-schemas.conf
ADD     ./config/opt_graphite_webapp_graphite_initial_data.json /opt/graphite/webapp/graphite/initial_data.json
ADD     ./config/opt_graphite_webapp_graphite_local_settings.py /opt/graphite/webapp/graphite/local_settings.py
ADD     ./config/opt_graphite_conf_graphite_wsgi.py /opt/graphite/conf/graphite_wsgi.py

# Configure grafana
ADD     ./config/opt_grafana_config.js /opt/grafana/config.js

# Configure elasticsearch
ADD     ./config/usr_local_bin_elasticsearch-start /usr/local/bin/elasticsearch-start
RUN \
  chmod 755 /usr/local/bin/elasticsearch-start

# Configure nginx
ADD     ./config/etc_nginx_nginx.conf /etc/nginx/nginx.conf

# Configure supervisord
ADD     ./config/etc_supervisor_supervisord.conf /etc/supervisor/supervisord.conf


# ----------------------- #
#     Setup runscript     #
# ----------------------- #

ADD     ./bin /bin
RUN \
  chmod 755 /bin/monitor-run


# -------------------- #
#     Expose ports     #
# -------------------- #

# expose nginx, StatsD (UDP) & StatsD Management
EXPOSE \
  80 2003 2004 7002 8125/udp 8126


# ------------------ #
#     Entrypoint     #
# ------------------ #

ENTRYPOINT \
  ["/bin/monitor-run"]

# docker build [--rm] -t <user>/openvpn .
# docker run -v /data --name monitor-data busybox:ubuntu-14.04
# docker run -d -v /etc/localtime:/etc/localtime:ro --volumes-from monitor-data -p 80:80 -p 2003:2003 -p 2004:2004 -p 7002:7002 -p 8125:8125/udp -p 8126:8126 --name monitor <user>/monitor
