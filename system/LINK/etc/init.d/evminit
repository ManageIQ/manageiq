#!/bin/bash
# chkconfig: 2345 01 15
# description: Initializes the evm environment
#


# Some variables to shorten things
VMDBDIR=/var/www/miq/vmdb
EVMLOG=$VMDBDIR/log/evm.log
PID_DIR=$VMDBDIR/tmp/pids


# Log to evm.log that appliance booted
echo `date -u` 'EVMINIT   EVM Appliance Booted' >> $EVMLOG
rm -rfv $PID_DIR/evm.pid >> $EVMLOG


# Rescan for LVM Physical Volumes since RHEV DirectLUN PV's aren't always found.
pvscan
