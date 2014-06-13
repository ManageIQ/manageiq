#!/bin/bash
[[ -s /etc/default/evm ]] && source /etc/default/evm

pushd /var/www/miq/vmdb
  bundle install $BUNDLE_CLI_OPTIONS

  pushd /var/www/miq
    # rake after bundler may install rake
    rake build:shared_objects --trace
  popd

  # rails compile tasks loads environment which needs above shared objects
  RAILS_ENV=production rake evm:compile_assets
popd

#this is for the black console
sed -i 's@ACTIVE_CONSOLES=/dev/tty\[1-6\]@ACTIVE_CONSOLES=/dev/tty3@' /etc/sysconfig/init

# httpd needs to connect to backend workers on :3000 and :4000
setsebool -P httpd_can_network_connect on

# backup the default ssl.conf
mv /etc/httpd/conf.d/ssl.conf{,.orig}

# https://bugzilla.redhat.com/show_bug.cgi?id=1020042
cat <<'EOF' > /etc/httpd/conf.d/ssl.conf
# This file intentionally left blank.  CFME maintains its own SSL
# configuration.  The presence of this file prevents the version
# supplied by mod_ssl from being installed when the mod_ssl package is
# upgraded.
EOF

/usr/sbin/semanage fcontext -a -t httpd_log_t "/var/www/miq/vmdb/log(/.*)?"
[ -x /sbin/restorecon ] && /sbin/restorecon -R -v /var/www/miq/vmdb/log
[ -x /sbin/restorecon ] && /sbin/restorecon -R -v /etc/sysconfig
# relabel the pg_log directory in postgresql datadir, but defer restorecon
# until after the database is initialized during firstboot configuration
/usr/sbin/semanage fcontext -a -t var_log_t "/opt/rh/postgresql92/root/var/lib/pgsql/data/pg_log(/.*)?"

# Copy the postgres template yml to database.yml if it doesn't exist
db_yml="/var/www/miq/vmdb/config/database.yml"
db_template="/var/www/miq/vmdb/config/database.pg.yml"
[ ! -f $db_yml ] && [ -f $db_template ] && cp $db_template $db_yml
