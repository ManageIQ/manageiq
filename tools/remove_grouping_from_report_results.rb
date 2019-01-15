#!/usr/bin/env ruby
require 'optimist'

opts = Optimist.options do
  banner "Remove extras[:grouping] from MiqReportResult#report column.\n\nUsage: ruby #{$PROGRAM_NAME} [options]\n\nOptions:\n\t"
  opt :dry_run,    "For testing, rollback any changes when the script exits.", :short => :none, :default => false
  opt :batch_size, "Limit memory usage by process this number of report results at a time.",    :default => 50
  opt :count,      "Stop checking after this number of report results.",                        :default => 0
end

puts "Using options: #{opts.inspect}\n\n"

if defined?(Rails)
  puts "Warning: Rails is already loaded!  Please do not invoke using rails runner. Exiting with help text.\n\n"
  Optimist.educate
end

# Load rails after optimist options are set.  No one wants to wait for -h.
require File.expand_path('../config/environment', __dir__)

# Wrap all changes in a transaction and roll them back if dry-run or an error occurs.
ActiveRecord::Base.connection.begin_transaction(:joinable => false)

if opts[:dry_run]
  puts "Running in dry-run, all changes will be rolled back when complete."

  at_exit do
    ActiveRecord::Base.connection.rollback_transaction
  end
end

start = Time.now.utc
total = 0
fixed = 0

MiqReportResult.find_each(:batch_size => opts[:batch_size]).with_index do |rr, i|
  begin
    break if opts[:count].positive? && i == opts[:count]
    total += 1

    next if rr.report.nil? || rr.report.extras.nil?

    if rr.report.extras.key?(:grouping)
      rr.report.extras.except!(:grouping)
      rr.save!
      if rr.reload.report.extras.key?(:grouping)
        puts "MiqReportResult: #{rr.id} could NOT be fixed"
      else
        puts "MiqReportResult: #{rr.id} fixed"
        fixed += 1
      end
    else
      puts "MiqReportResult: #{rr.id} doesn't need fixing"
    end
  rescue => err
    puts "\nWarning: Rolling back all changes since an error occurred on MiqReportResult with id: #{rr.try(:id)}: #{err.message}"
    ActiveRecord::Base.connection.rollback_transaction unless opts[:dry_run]
    exit 1
  end
end

ActiveRecord::Base.connection.commit_transaction unless opts[:dry_run]
puts "\nProcessed #{total} rows. #{fixed} were fixed. #{Time.now.utc - start} seconds"
