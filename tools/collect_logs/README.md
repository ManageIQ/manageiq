To collect logs manually, please use the collect_archive_logs.sh and/or collect_current_logs.sh scripts within this collect_logs directory depending on the information that is requested.
Use the exclude_files file to add any files you don't want included in log collection.

If you need NFS, Samba, or some other type of shared storage to collect logs, you can mount the storage to the /mnt/log_collection directory, and we will use that instead of the /var/www/miq/vmdb/log directory.
