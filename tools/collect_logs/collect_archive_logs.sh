#!/bin/bash

# save directory from which command is initiated
collect_logs_directory=$(pwd)

# determine where to write the logs to
if mountpoint /mnt/log_collection >/dev/null; then
    base_log_dir="/mnt/log_collection"
else
    base_log_dir="/var/www/miq/vmdb"
fi
pushd ${base_log_dir}
mkdir -p log

# eliminate any prior collected logs to make sure that only one collection is current
rm -f log/evm_full_archive_$(uname -n)* log/evm_archived_$(uname -n)*

# Source in the file so that we can call postgresql functions
source /etc/default/evm

tarball="log/evm_archive_$(uname -n)_$(date +%Y%m%d_%H%M%S).tar.xz"

if [[ -n "$APPLIANCE_PG_DATA" && -d "$APPLIANCE_PG_DATA/log" ]]; then
    echo "This ManageIQ appliance has a Database server and is running version: $(psql --version)"
    echo " Log collection starting:"
    XZ_OPT=-9 tar -cJvf ${tarball} --sparse --warning=no-file-changed -X $collect_logs_directory/exclude_files BUILD GUID VERSION log/* config/* /var/log/* log/apache/* $APPLIANCE_PG_DATA/log/* $APPLIANCE_PG_DATA/postgresql.conf
else
    echo "This ManageIQ appliance is not a Database server"
    echo " Log collection starting:"
    XZ_OPT=-9 tar -cJvf ${tarball} --sparse --warning=no-file-changed -X $collect_logs_directory/exclude_files BUILD GUID VERSION log/* config/* /var/log/* log/apache/*
fi

# and restore previous current directory
popd

# let the user know where the archive is
echo "Archive Written To: ${base_log_dir}/${tarball}"
