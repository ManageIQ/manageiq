ARG IMAGE_REF=latest-kasparov
FROM manageiq/manageiq-ui-worker:${IMAGE_REF}
MAINTAINER ManageIQ https://github.com/ManageIQ/manageiq

ENV DATABASE_URL=postgresql://root@localhost/vmdb_production?encoding=utf8&pool=5&wait_timeout=5

RUN dnf -y --disableplugin=subscription-manager --setopt=tsflags=nodocs install \
      memcached               \
      postgresql-server       \
      mod_ssl                 \
      &&                      \
    dnf clean all

## Copy/link the appliance files again so that we get ssl
RUN source /etc/default/evm && \
    $APPLIANCE_SOURCE_DIRECTORY/setup && \
    mv /etc/httpd/conf.d/ssl.conf{,.orig} && \
    echo "# This file intentionally left blank. ManageIQ maintains its own SSL configuration" > /etc/httpd/conf.d/ssl.conf

## Overwrite entrypoint from pods repo
COPY docker-assets/entrypoint /usr/local/bin

EXPOSE 443

LABEL name="manageiq"

VOLUME "/var/lib/pgsql/data"
VOLUME ${APP_ROOT}
