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
/usr/sbin/semanage fcontext -a -t cert_t "/var/www/miq/vmdb/certs(/.*)?"
/usr/sbin/semanage fcontext -a -t logrotate_exec_t /var/www/miq/system/logrotate_free_space_check.sh

[ -x /sbin/restorecon ] && /sbin/restorecon -R -v /var/www/miq/vmdb/log
[ -x /sbin/restorecon ] && /sbin/restorecon -R -v /etc/sysconfig
[ -x /sbin/restorecon ] && /sbin/restorecon -R -v /var/www/miq/vmdb/certs
[ -x /sbin/restorecon ] && /sbin/restorecon -R -v /var/www/miq/system/logrotate_free_space_check.sh

# relabel the pg_log directory in postgresql datadir, but defer restorecon
# until after the database is initialized during firstboot configuration
/usr/sbin/semanage fcontext -a -t var_log_t "/opt/rh/postgresql92/root/var/lib/pgsql/data/pg_log(/.*)?"
# setup label for postgres client certs, but relabel after dir is created
/usr/sbin/semanage fcontext -a -t cert_t "/root/.postgresql(/.*)?"
# will remove this once app is no longer running as root
/usr/sbin/semanage fcontext -a -t user_home_dir_t "/root(/)?"
/sbin/restorecon /root
