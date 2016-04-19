#!/bin/sh
[[ -d /var/opt/rh/rh-postgresql94/lib/pgsql/data/base ]] && exit 0
[[ -s /etc/default/evm ]] && source /etc/default/evm
echo "Initializing Appliance, please wait ..." > /dev/tty1
appliance_console_cli --region 0 --internal --password smartvm
