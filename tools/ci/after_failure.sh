#!/bin/bash
set -v

echo "Errors and warnings in log files"
echo log/*
egrep -i "warn|error" log/*.log

set +v
