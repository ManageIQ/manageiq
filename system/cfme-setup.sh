#!/bin/bash
[[ -s /etc/default/evm ]] && source /etc/default/evm

pushd /var/www/miq/vmdb
  bundle install $BUNDLE_CLI_OPTIONS

  pushd /var/www/miq
    # rake after bundler may install rake
    rake build:shared_objects --trace
  popd

  # rails compile tasks loads environment which needs above shared objects
  # There is no database.yml. Bogus database parameters appeases rails.
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

MIQ_ROOT="/var/www/miq"
SOURCE_IPTABLES="$MIQ_ROOT/system/TEMPLATE/etc/sysconfig/iptables"
SOURCE_CTRL_ALT_DEL="$MIQ_ROOT/system/TEMPLATE/etc/init/control-alt-delete.override"

# Incorporate the iptable updates
if [[ -f $SOURCE_IPTABLES ]]; then
  /sbin/iptables-save > /etc/sysconfig/iptables.SYSTEM
  /sbin/iptables-restore $SOURCE_IPTABLES
  /sbin/service iptables save
fi

# Copy the ctrl-alt-del override if it doesn't exist
if [[ ! -f /etc/init/control-alt-delete.override ]] && [[ -f $SOURCE_CTRL_ALT_DEL ]] ; then
  cp $SOURCE_CTRL_ALT_DEL /etc/init
fi

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
