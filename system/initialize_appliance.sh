#!/bin/bash

[[ ! -f "/var/www/miq/vmdb/certs/v2_key" ]] && appliance_console_cli --key
