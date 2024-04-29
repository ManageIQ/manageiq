ARG IMAGE_REF=latest
FROM docker.io/manageiq/manageiq-ui-worker:${IMAGE_REF}
MAINTAINER ManageIQ https://github.com/ManageIQ/manageiq

ENV DATABASE_URL=postgresql://root@localhost/vmdb_production?encoding=utf8&pool=5&wait_timeout=5

RUN echo "# This file intentionally left blank. ManageIQ maintains its own SSL configuration" > /etc/httpd/conf.d/ssl.conf && \
    dnf -y --setopt=tsflags=nodocs install \
      manageiq-appliance      \
      memcached               \
      postgresql-server       \
      mod_ssl                 \
      &&                      \
    dnf clean all && \
    rm -rf /var/cache/dnf

## Overwrite entrypoint from pods repo
COPY container-assets/entrypoint /usr/local/bin

EXPOSE 443

LABEL name="manageiq"

VOLUME "/var/lib/pgsql/data"
VOLUME ${APP_ROOT}
