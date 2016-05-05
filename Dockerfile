FROM centos:7
ENV container docker
MAINTAINER ManageIQ https://github.com/ManageIQ/manageiq-appliance-build

# Set ENV, LANG only needed if building with docker-1.8
ENV LANG en_US.UTF-8
ENV TERM xterm
ENV APP_ROOT /var/www/miq/vmdb
ENV APPLIANCE_ROOT /opt/manageiq/manageiq-appliance
ENV SSUI_ROOT /opt/manageiq/manageiq-ui-self_service

# Fetch postgresql 9.4 COPR and pglogical repos
RUN curl -sSLko /etc/yum.repos.d/rhscl-rh-postgresql94-epel-7.repo \
https://copr-fe.cloud.fedoraproject.org/coprs/rhscl/rh-postgresql94/repo/epel-7/rhscl-rh-postgresql94-epel-7.repo && \
curl -sSLko /etc/yum.repos.d/ncarboni-pglogical-SCL-epel-7.repo \
https://copr.fedorainfracloud.org/coprs/ncarboni/pglogical-SCL/repo/epel-7/ncarboni-pglogical-SCL-epel-7.repo

## Install EPEL repo, yum necessary packages for the build without docs, clean all caches
RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum -y install --setopt=tsflags=nodocs \
                   bison                   \
                   bzip2                   \
                   cmake                   \
                   file                    \
                   gcc-c++                 \
                   git                     \
                   libffi-devel            \
                   libtool                 \
                   libxml2-devel           \
                   libxslt-devel           \
                   libyaml-devel           \
                   make                    \
                   memcached               \
                   net-tools               \
                   nodejs                  \
                   openssl-devel           \
                   patch                   \
                   rh-postgresql94-postgresql-server \
                   rh-postgresql94-postgresql-devel  \
                   rh-postgresql94-postgresql-pglogical-output \
                   rh-postgresql94-postgresql-pglogical \
                   readline-devel          \
                   sqlite-devel            \
                   sysvinit-tools          \
                   which                   \
                   httpd                   \
                   mod_ssl                 \
                   mod_auth_kerb           \
                   mod_authnz_pam          \
                   mod_intercept_form_submit \
                   mod_lookup_identity     \
                   initscripts             \
                   npm                     \
                   chrony                  \
                   psmisc                  \
                   lvm2                    \
                   openldap-clients        \
                   gdbm-devel              \
                   &&                      \
    yum clean all

# Add persistent data volume for postgres
VOLUME [ "/var/opt/rh/rh-postgresql94/lib/pgsql/data" ]

# Download chruby and chruby-install, install, setup environment, clean all
RUN curl -sL https://github.com/postmodern/chruby/archive/v0.3.9.tar.gz | tar xz && \
    cd chruby-0.3.9 && make install && scripts/setup.sh && \
    echo "gem: --no-ri --no-rdoc --no-document" > ~/.gemrc && \
    echo "source /usr/local/share/chruby/chruby.sh" >> ~/.bashrc && \ 
    curl -sL https://github.com/postmodern/ruby-install/archive/v0.6.0.tar.gz | tar xz && \
    cd ruby-install-0.6.0 && make install && ruby-install ruby 2.2.5 -- --disable-install-doc && \
    echo "chruby ruby-2.2.5" >> ~/.bash_profile && \
    rm -rf /chruby-* && rm -rf /usr/local/src/* && yum clean all

## GIT clone manageiq-appliance and self-service UI repo (SSUI)
RUN git clone --depth 1 https://github.com/ManageIQ/manageiq-appliance.git ${APPLIANCE_ROOT} && \
git clone --depth 1 https://github.com/ManageIQ/manageiq-ui-self_service.git ${SSUI_ROOT} && \
ln -vs ${APP_ROOT} /opt/manageiq/manageiq

## Create approot, ADD miq
RUN mkdir -p ${APP_ROOT}
ADD . ${APP_ROOT}

## Setup environment

RUN ${APPLIANCE_ROOT}/setup && \
echo "export PATH=\$PATH:/opt/rubies/ruby-2.2.5/bin" >> /etc/default/evm && \
mkdir ${APP_ROOT}/log/apache && \
mv /etc/httpd/conf.d/ssl.conf{,.orig} && \
echo "# This file intentionally left blank. ManageIQ maintains its own SSL configuration" > /etc/httpd/conf.d/ssl.conf && \
echo "export APP_ROOT=${APP_ROOT}" >> /etc/default/evm

## Change workdir to application root, build/install gems
WORKDIR ${APP_ROOT}
RUN source /etc/default/evm && \
/usr/bin/memcached -u memcached -p 11211 -m 64 -c 1024 -l 127.0.0.1 -d && \
npm install npm -g && \
npm install gulp bower -g && \
gem install bundler -v ">=1.8.4" && \
bin/setup --no-db --no-tests && \
rake evm:compile_assets && \
rake evm:compile_sti_loader && \
rm -rvf /opt/rubies/ruby-2.2.5/lib/ruby/gems/2.2.0/cache/* && \
bower cache clean && \
npm cache clean

## Build SSUI
RUN source /etc/default/evm && \
cd ${SSUI_ROOT} && \
npm install && \
bower -F --allow-root install && \
gulp build && \
bower cache clean && \
npm cache clean

## Copy appliance-initialize script and service unit file
COPY docker-assets/appliance-initialize.service /usr/lib/systemd/system
COPY docker-assets/appliance-initialize.sh /bin

## Scripts symblinks
RUN ln -s /var/www/miq/vmdb/docker-assets/docker_initdb /usr/bin

## Enable services on systemd
RUN systemctl enable memcached appliance-initialize evmserverd evminit evm-watchdog miqvmstat miqtop

## Expose required container ports
EXPOSE 80 443

# Atomic Labels
# The UNINSTALL label by DEFAULT will attempt to delete a container (rm) and image (rmi) if the container NAME is the same as the actual IMAGE
# NAME is set via -n flag to ALL atomic commands (install,run,stop,uninstall)

LABEL name="manageiq" \
          vendor="ManageIQ" \
          version="Capablanca" \
          release="latest" \
          architecture="x86_64" \
          url="http://manageiq.org/" \
          summary="ManageIQ appliance image" \
          description="ManageIQ is a management and automation platform for virtual, private, and hybrid cloud infrastructures." \
          INSTALL='docker run -ti --privileged \
                    --name ${NAME}_volume \
                    --entrypoint /usr/bin/docker_initdb \
                    $IMAGE' \
          RUN='docker run -di --privileged \
                    --name ${NAME}_run \
                    -v /etc/localtime:/etc/localtime:ro \
                    --volumes-from ${NAME}_volume \
                    -p 80:80 \
                    -p 443:443 \
                    $IMAGE' \
          STOP='docker stop ${NAME}_run && \
          echo "Container ${NAME}_run has been stopped"' \
          UNINSTALL='docker rm -v ${NAME}_volume ${NAME}_run && \
          echo "Uninstallation complete"'

## Call systemd to bring up system
CMD [ "/usr/sbin/init" ]
