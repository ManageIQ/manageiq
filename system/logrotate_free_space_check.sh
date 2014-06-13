#!/bin/sh
file=$1
logger_file=/var/www/miq/vmdb/log/appliance_console.log
logvol_free_space=`df -k $file | awk '{ print $3 }' | tail -n 1`
existing_log_size=`du -k $file | awk '{ print $1 }' | tail -n 1`
size_needed=$(($existing_log_size+($existing_log_size/5)))
echo "$(date) Checking for enough free space to rotate: $file" >> $logger_file
echo "$(date)   File size:                 $existing_log_size" >> $logger_file
echo "$(date)   Space required to rotate:  $size_needed"       >> $logger_file
echo "$(date)   Available space on volume: $logvol_free_space" >> $logger_file

if [ $size_needed -le $logvol_free_space ]; then
  echo "$(date)   Rotating file..." >> $logger_file
  exit 0
else
  echo "$(date)   Skipping file, Not enough free space on disk." >> $logger_file
  exit 1
fi
