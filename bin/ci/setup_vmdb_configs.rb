#!/usr/bin/env ruby
require_relative '../../lib/manageiq/environment'
ManageIQ::Environment.ensure_config_files
ManageIQ::Environment.create_database_user
