# This script is run by ApplianceConsole::DatabaseConfiguration when joining a region.

$log.info("MIQ(#{$0}) Joining region...")

config = Rails.configuration.database_configuration[Rails.env]
raise "Failed to retrieve database configuration for Rails.env [#{Rails.env}]" if config.nil?

$log.info("MIQ(#{$0}) Establishing connection with #{config.except("password").inspect}")
class RemoteDatabase < ApplicationRecord
end
RemoteDatabase.establish_connection(config)
new_region = RemoteDatabase.region_number_from_sequence.to_i

region_file = Rails.root.join("REGION")
old_region = region_file.exist? ? region_file.read.to_i : 0

if new_region != old_region
  $log.info("MIQ(#{$0}) Changing REGION file from [#{old_region}] to [#{new_region}]. Restart to use the new region.")
  region_file.write(new_region)
end

$log.info("MIQ(#{$0}) Joining region...Complete")
