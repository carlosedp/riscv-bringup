FROM debian:sid
LABEL maintainer="Andras Mitzki <andras.mitzki@balabit.com>"


RUN apt-get update -qq && apt-get install -y \
    wget \
    gnupg2

RUN apt-get update -qq && apt-get install -y \
    libdbd-mysql libdbd-pgsql libdbd-sqlite3 syslog-ng

ADD syslog-ng.conf /etc/syslog-ng/syslog-ng.conf

RUN find /usr/lib/ -name 'libjvm.so*' | xargs dirname | tee --append /etc/ld.so.conf.d/openjdk-libjvm.conf
RUN ldconfig

EXPOSE 514/udp
EXPOSE 514/tcp
EXPOSE 601/tcp
EXPOSE 6514/tcp

HEALTHCHECK --interval=2m --timeout=3s --start-period=30s CMD /usr/sbin/syslog-ng-ctl stats || exit 1

ENTRYPOINT ["/usr/sbin/syslog-ng", "-F"]
