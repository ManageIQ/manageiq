
DIR=$(dirname "$(readlink -f "$0")")
'cp' -b $DIR/rhconsulting_service_dialogs.rake /var/www/miq/vmdb/lib/tasks/
