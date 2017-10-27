#!/usr/bin/env bash

# ensure pathname correct when runs in a different place
basedir=$(dirname $0)
# default postgresql password: smartvm
export PGPASSWORD="${PGPASSWORD:-smartvm}"

# Run step 1, 3 and 4 in sequence, assume step 2 has done before.
${basedir}/../pg_inspector.rb connections
${basedir}/../pg_inspector.rb human
${basedir}/../pg_inspector.rb locks

# remove first only if all steps success
if [ $? -ne '0' ]; then
  echo "Fails to generate lock output."
  exit 1
fi
rm -f pg_inspector_output.tar.gz

# collect the output
tar czf pg_inspector_output.tar.gz /var/www/miq/vmdb/log/pg_inspector*
