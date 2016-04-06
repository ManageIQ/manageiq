#!/bin/bash

# Source EVM environment 
[ -f /etc/default/evm ] &&  . /etc/default/evm

cd ${BASEDIR}

start() {
  bundle exec rake evm:start
  RETVAL=$?
  return $RETVAL
}

stop() {
  bundle exec rake evm:stop
  RETVAL=$?
  return $RETVAL
}

restart() {
  bundle exec rake evm:restart
  RETVAL=$?
  return $RETVAL
}

status() {
  bundle exec rake evm:status
  RETVAL=$?
  return $RETVAL
}

# See how we were called.
case "$1" in
  start)
  start
  ;;
  stop)
  stop
  ;;
  status)
  status
  ;;
  restart)
  restart
  ;;
  *)
  echo $"Usage: $prog {start|stop|restart|status}"
  exit 1
esac

exit $RETVAL
