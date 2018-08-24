FROM ubuntu:18.04 as base
  
ENV DEBIAN_FRONTEND=noninteractive TERM=xterm
RUN echo "export > /etc/envvars" >> /root/.bashrc && \
    echo "export PS1='\[\e[1;31m\]\u@\h:\w\\$\[\e[0m\] '" | tee -a /root/.bashrc /etc/skel/.bashrc && \
    echo "alias tcurrent='tail /var/log/*/current -f'" | tee -a /root/.bashrc /etc/skel/.bashrc

RUN apt-get update
RUN apt-get install -y locales && locale-gen en_US.UTF-8 && dpkg-reconfigure locales
ENV LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

# Runit
RUN apt-get install -y --no-install-recommends runit
CMD bash -c 'export > /etc/envvars && /usr/bin/runsvdir /etc/service'

# Utilities
RUN apt-get install -y --no-install-recommends vim less net-tools inetutils-ping wget curl git telnet nmap socat dnsutils netcat tree htop unzip sudo software-properties-common jq psmisc iproute2 python ssh rsync gettext-base

RUN apt-get -y install \
    libltdl7 \
    libcppunit-dev \
    libsasl2-dev \
    libxml2-dev \
    libkrb5-dev \
    libdb-dev \
    libnetfilter-conntrack-dev \
    libexpat1-dev \
    libcap2-dev \
    libldap2-dev \
    libpam0g-dev \
    libgnutls28-dev \
    libssl-dev \
    libdbi-perl \
    libecap3 \
    libecap3-dev

FROM base as build

RUN apt-get install -y devscripts build-essential fakeroot debhelper dh-autoreconf cdbs

RUN wget -O - http://www.squid-cache.org/Versions/v4/squid-4.2.tar.gz | tar zx
RUN cd squid* && \
    ./configure \
    --prefix=/usr \
    --localstatedir=/var \
    --libexecdir=${prefix}/lib/squid \
    --datadir=${prefix}/share/squid \
    --sysconfdir=/etc/squid \
    --with-default-user=proxy \
    --with-logdir=/var/log/squid \
    --with-pidfile=/var/run/squid.pid \
    --with-openssl \
    --with-filedescriptors=65536 \
    --with-large-files \
    --enable-inline \
    --enable-async-io=8 \
    --enable-storeio="ufs,aufs,diskd,rock" \
    --enable-removal-policies="lru,heap" \
    --enable-delay-pools \
    --enable-cache-digests \
    --enable-underscores \
    --enable-icap-client \
    --enable-follow-x-forwarded-for \
    --enable-auth-basic="DB,fake,getpwnam,LDAP,NCSA,NIS,PAM,POP3,RADIUS,SASL,SMB" \
    --enable-auth-digest="file,LDAP" \
    --enable-auth-negotiate="kerberos,wrapper" \
    --enable-auth-ntlm="fake" \
    --enable-external-acl-helpers="file_userip,kerberos_ldap_group,LDAP_group,session,SQL_session,unix_group,wbinfo_group" \
    --enable-url-rewrite-helpers="fake" \
    --enable-eui \
    --enable-esi \
    --enable-icmp \
    --enable-zph-qos \
    --enable-ssl \
    --enable-ssl-crtd \
    --disable-translation \
    --disable-arch-native

RUN cd squid* && \
    make -j$(nproc) && \
    make install

FROM base as final
COPY --from=build /etc/squid /etc/squid
COPY --from=build /run/squid /run/squid
COPY --from=build /lib/squid /lib/squid
COPY --from=build /usr/sbin/squid /usr/sbin/squid
COPY --from=build /var/cache/squid /var/cache/squid
COPY --from=build /var/log/squid /var/log/squid
COPY --from=build /share/squid /share/squid

COPY squid.conf /etc/squid/

# Add runit services
COPY sv /etc/service 
ARG BUILD_INFO
LABEL BUILD_INFO=$BUILD_INFO
