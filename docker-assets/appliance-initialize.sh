#!/bin/bash

# Source EVM environment 
[ -f /etc/default/evm ] &&  . /etc/default/evm
[[ -s ${CONTAINER_SCRIPTS_ROOT}/container-deploy-common.sh ]] && source "${CONTAINER_SCRIPTS_ROOT}/container-deploy-common.sh"

function create_v2_key() {
  V2_KEY=$(ruby -ropenssl -rbase64 -e 'puts Base64.strict_encode64(Digest::SHA256.digest(OpenSSL::Random.random_bytes(32))[0, 32])')
  write_v2_key
  unset V2_KEY
}

# Check postgres server DB init status, if necessary, initdb, start/enable service and inject MIQ role

echo "== Checking MIQ database status =="

[[ -d /var/opt/rh/rh-postgresql95/lib/pgsql/data/base ]]
if [ $? -eq 0 ]; then
  echo "** DB already initialized"
  exit 0
else
  echo "** DB has not been initialized"

  echo "** Launching initdb"
  su postgres -c "initdb -D ${APPLIANCE_PG_DATA}"
  test $? -ne 0 && echo "!! Failed to initdb" && exit 1

  echo "** Starting postgresql"
  su postgres -c "pg_ctl -D ${APPLIANCE_PG_DATA} start"
  test $? -ne 0 && echo "!! Failed to start postgresql service" && exit 1

  sleep 5

  echo "** Creating MIQ role"
  su postgres -c "psql -c \"CREATE ROLE root SUPERUSER LOGIN PASSWORD 'smartvm'\""
  test $? -ne 0 && echo "!! Failed to inject MIQ root Role" && exit 1

  # Check if memcached is running, if not start it
  pidof memcached
  test $? -ne 0 && /usr/bin/memcached -u memcached -p 11211 -m 64 -c 1024 -l 127.0.0.1 -d

  echo "** Starting DB setup"
  pushd ${APP_ROOT}
    create_v2_key
    bundle exec rake evm:db:reset
  popd

  echo "** MIQ database has been initialized"

  generate_miq_server_cert.sh
  exit 0
fi
