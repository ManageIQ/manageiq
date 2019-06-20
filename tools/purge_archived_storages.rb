#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require "optimist"

opts = Optimist.options do
  opt :dry_run, "Just print out what would be done without modifying anything", :type => :boolean, :default => true
end

if opts[:dry_run]
  puts "**** This is a dry run and will not modify the database"
  puts "     To actually purge the storages pass --no-dry-run"
else
  puts "**** This will modify your database ****"
  puts "     Press Enter to Continue: "
  STDIN.getc
end

active_storage_ids = HostStorage.pluck(:storage_id).uniq
archived_storages = Storage.where.not(:id => active_storage_ids).pluck(:id, :name)

if archived_storages.empty?
  puts "No archived storages found"
else
  puts "Deleting the following storages:"
  puts archived_storages.map { |id, name| "ID [#{id}] Name [#{name}]" }.join("\n")
end

return if opts[:dry_run]

archived_storage_ids = archived_storages.map(&:first)
Storage.destroy(archived_storage_ids)
