#!/usr/bin/env bash
basedir=$(dirname $0)
export PGPASSWORD="${PGPASSWORD:-smartvm}"

${basedir}/../pg_inspector.rb servers
