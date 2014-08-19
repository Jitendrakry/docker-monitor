# docker-monitor

Docker image running Carbon, Graphite, StatsD & Grafana


### Instructions

Build the docker image
```
docker build [--rm] -t <user>/monitor .
```

Run a data container
```
docker run -v /data --name monitor-data busybox:ubuntu-14.04
```

Run the container
```
docker run -d -v /etc/localtime:/etc/localtime:ro --volumes-from monitor-data -p 80:80 -p 2003:2003 -p 2004:2004 -p 7002:7002 -p 8125:8125/udp -p 8126:8126 --name monitor <user>/monitor
```
