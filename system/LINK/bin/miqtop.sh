#!/bin/sh
# chkconfig: 2345 85 15
# description: miqtop starts both top and vmstat and outputs to the miq logs.
#

### Variables ###
LOG_DIR=/var/www/miq/vmdb/log
PID_DIR=/var/www/miq/vmdb/tmp/pids
HOURLY_FILE=/etc/cron.hourly/miq_top_hourly
RETVAL=0

run_top() {
  echo "miqtop: start: date time is-> $(date) $(date +%z)" >> $LOG_DIR/top_output.log
  COLUMNS=512 top -b -d 60 -n 9999999 >> $LOG_DIR/top_output.log &
}

run_vmstat() {
  echo "miqtop: start: date time is-> $(date) $(date +%z)" >> $LOG_DIR/vmstat_output.log
  vmstat -a -n 60 >> $LOG_DIR/vmstat_output.log &
}

# Every hour, write the date time into the logs to provide some time context
rm -f HOURLY_FILE
echo "#!/bin/sh
#
echo \"miqtop: timesync: date time is-> \$(date) \$(date +%z)\" >> /var/www/miq/vmdb/log/top_output.log
echo \"miqtop: timesync: date time is-> \$(date) \$(date +%z)\" >> /var/www/miq/vmdb/log/vmstat_output.log
/bin/miqtop start > /dev/null 2>&1" > $HOURLY_FILE

chmod 755 /etc/cron.hourly/miq_top_hourly

start_processes() {
  for p in "top" "vmstat"
  do
    pid_file=$PID_DIR/$p.pid
    if [ -e $pid_file ]
    then # start the process if the pid file doesn't exist and it's not currently running - creating a new .pid file
     PID=`cat $pid_file`
     echo "miqtop: $p already started $PID"
    else
      run_$p
      echo $! >> $pid_file
      echo "miqtop: $p: started $!"
    fi
  done
}

stop_processes() {
  for p in "top" "vmstat"
  do
    # stop the processes based on the pid files
    pid_file=$PID_DIR/$p.pid

    # if the pid file exists, kill the process if it is running and remove the pid file
    if [ -e $pid_file ]; then
      PID=`cat $pid_file`
      echo "miqtop: stop: date time is-> $(date) $(date +%z)" >> $LOG_DIR/${p}_output.log

      ps -A | grep -E "$p" | grep -q "$PID"
      if [ $? -eq 0 ]; then
        kill $PID
      fi
      rm -f $pid_file
      echo "miqtop: $p: stopped"
    else
      echo "miqtop: $p: already stopped, no pid file: $pid_file"
    fi
  done
}

show_status() {
  for p in "top" "vmstat"
  do
    # Check if the pids in the .pid files are currently running
    pid_file=$PID_DIR/$p.pid
    if [ -e $pid_file ]; then
      PID=`cat $pid_file`
      ps -A | grep -E "$p" | grep -q "$PID"
      if [ $? -eq 0 ]; then
        echo "miqtop: $p running $PID"
      else
        echo "miqtop: $p not running"
      fi
    else
      # Not running if no pid file exists
      echo "miqtop: $p not running"
    fi
  done
}

clean_pid_files() {
  # Remove PID file if there is no running process for it
  PIDS=`find $PID_DIR -name "*.pid" |grep -E 'top|vmstat'`
  for f in $PIDS
  do
  if [ -e "$f" ]; then
    PID=`cat $f`
    ps -p $PID
    if [ $? -ne 0 ]; then
      rm -f $f
    fi
  fi
  done
}

case "$1" in
  start)
    #create pid directory
    mkdir -p $PID_DIR
    chown $USER:$USER $PID_DIR
    clean_pid_files
    start_processes
    RETVAL=$?
  ;;
  stop)
    stop_processes
    RETVAL=$?
  ;;
  restart)
    stop_processes
    start_processes
    RETVAL=$?
  ;;
  status)
    show_status
    RETVAL=$?
  ;;
  *)
    echo "Usage: "/bin/miqtop" {start|stop|restart|status}"
         exit 1
  ;;
esac

exit $RETVAL
