ARG IMAGE_REF=latest
FROM manageiq/manageiq-pods:frontend-${IMAGE_REF}
MAINTAINER ManageIQ https://github.com/ManageIQ/manageiq

## Set build ARG
ARG REF=master

ENV DATABASE_URL=postgresql://root@localhost/vmdb_production?encoding=utf8&pool=5&wait_timeout=5

RUN yum -y install --setopt=tsflags=nodocs \
                   memcached               \
                   postgresql-server       \
                   repmgr10                \
                   mod_ssl                 \
                   openssh-clients         \
                   openssh-server          \
                   &&                      \
    yum clean all

VOLUME [ "/var/lib/pgsql/data" ]

# Initialize SSH
RUN ssh-keygen -q -t dsa -N '' -f /etc/ssh/ssh_host_dsa_key && \
    ssh-keygen -q -t rsa -N '' -f /etc/ssh/ssh_host_rsa_key && \
    ssh-keygen -q -t rsa -N '' -f /root/.ssh/id_rsa && \
    cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys && \
    for key in /etc/ssh/ssh_host_*_key.pub; do echo "localhost $(cat ${key})" >> /root/.ssh/known_hosts; done && \
    echo "root:smartvm" | chpasswd && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/*

## Copy/link the appliance files again so that we get ssl
RUN ${APPLIANCE_ROOT}/setup && \
    mv /etc/httpd/conf.d/ssl.conf{,.orig} && \
    echo "# This file intentionally left blank. ManageIQ maintains its own SSL configuration" > /etc/httpd/conf.d/ssl.conf

## Copy appliance-initialize script and service unit file
COPY docker-assets/appliance-initialize.sh /usr/bin

EXPOSE 443 22

## Atomic Labels
# The UNINSTALL label by DEFAULT will attempt to delete a container (rm) and image (rmi) if the container NAME is the same as the actual IMAGE
# NAME is set via -n flag to ALL atomic commands (install,run,stop,uninstall)
LABEL name="manageiq" \
      vendor="ManageIQ" \
      version="Master" \
      release=${REF} \
      architecture="x86_64" \
      url="http://manageiq.org/" \
      summary="ManageIQ appliance image" \
      description="ManageIQ is a management and automation platform for virtual, private, and hybrid cloud infrastructures." \
      INSTALL='docker run -ti \
                --name ${NAME}_volume \
                --entrypoint /usr/bin/appliance-initialize.sh \
                $IMAGE' \
      RUN='docker run -di \
            --name ${NAME}_run \
            -v /etc/localtime:/etc/localtime:ro \
            --volumes-from ${NAME}_volume \
            -p 443:443 \
            $IMAGE' \
      STOP='docker stop ${NAME}_run && echo "Container ${NAME}_run has been stopped"' \
      UNINSTALL='docker rm -v ${NAME}_volume ${NAME}_run && echo "Uninstallation complete"'

LABEL io.k8s.description="ManageIQ is a management and automation platform for virtual, private, and hybrid cloud infrastructures." \
      io.k8s.display-name="ManageIQ" \
      io.openshift.expose-services="443:https" \
      io.openshift.tags="ManageIQ,miq,manageiq"
