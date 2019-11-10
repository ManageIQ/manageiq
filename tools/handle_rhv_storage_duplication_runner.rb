#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require_relative "handle_rhv_storage_duplication"
require 'ovirtsdk4'
require 'optimist'

opts = Optimist.options(ARGV) do
  banner "This will delete duplicate rhv storages created by changing the way we get set the storage location from your database\n" \
         "See https://github.com/ManageIQ/manageiq-providers-ovirt/pull/387\n" \
         "And https://bugzilla.redhat.com/show_bug.cgi?id=1697467"

  opt :dry_run,  "Dry Run, do not make any real db changes. Use it with the verbose option to see the changes", :short => "d"
  opt :verbose,  "Print out which storages are being removed", :short => "v"
end

HandleStorageDuplication.new(:dry_run => opts[:dry_run], :verbose => opts[:verbose]).handle_duplicates
