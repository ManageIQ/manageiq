#!/usr/bin/env bash
basedir=$(dirname $0)
password="${PGPASSWORD:-smartvm}"

# Run step 1, 3 and 4 in sequence, assume step 2 has done before.
${basedir}/../pg_inspector.rb connections
${basedir}/../pg_inspector.rb human
${basedir}/../pg_inspector.rb locks

# collect the output
tar czf pg_inspector_output.tar.gz ${basedir}/output
