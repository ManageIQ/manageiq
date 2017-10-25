#!/usr/bin/env bash

basedir=$(dirname $0)
absdir=$(realpath $basedir)

crontab -l 2>/dev/null | grep -v pg_inspector >crontab.tmp
echo "PATH=${PATH} # pg_inspector path to find ruby" >>crontab.tmp
echo "0 0 * * * ${absdir}/dump_server.sh" >>crontab.tmp
crontab crontab.tmp
rm -f crontab.tmp
