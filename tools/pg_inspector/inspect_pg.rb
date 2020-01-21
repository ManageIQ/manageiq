#!/usr/bin/env ruby

## Run pg_inspector using parameters given in local database.yml and v2 key.

if __FILE__ == $PROGRAM_NAME
  $LOAD_PATH.push(File.expand_path(File.join(__dir__, %w(.. .. lib))))
end

require 'yaml'
require 'manageiq-password'

BASE_DIR = __dir__
LOG_DIR = '/var/www/miq/vmdb/log'.freeze
DATABASE_YML_FILE_PATH = "#{BASE_DIR}/../../config/database.yml".freeze
V2_KEY_FILE_PATH = "#{BASE_DIR}/../../certs/v2_key".freeze

production_db = YAML.load_file(DATABASE_YML_FILE_PATH)["production"]

db_user = production_db["username"]
db_password_encrypt = production_db["password"]
db_password = ManageIQ::Password.try_decrypt(db_password_encrypt)
db_host = production_db["host"]

# system "#{BASE_DIR}/../pg_inspector.rb -h"
ENV['PGPASSWORD'] = db_password
system("#{BASE_DIR}/../pg_inspector.rb connections -u #{db_user} -s #{db_host} -i")
if File.exist?(Pathname.new(LOG_DIR).join('pg_inspector_server.yml'))
  puts("pg_inspector_server.yml already exists, skip generating.")
else
  system("#{BASE_DIR}/../pg_inspector.rb servers -u #{db_user} -s #{db_host}")
end
system("#{BASE_DIR}/../pg_inspector.rb human")
success = system("#{BASE_DIR}/../pg_inspector.rb locks")
unless success
  exit(1)
end
