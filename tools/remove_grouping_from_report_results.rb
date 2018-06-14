#!/usr/bin/env ruby
require 'trollop'

opts = Trollop.options do
  banner "Remove extras[:grouping] from MiqReportResult#report column.\n\nUsage: ruby #{$PROGRAM_NAME} [options]\n\nOptions:\n\t"
  opt :dry_run,    "For testing, rollback any changes when the script exits.", :short => :none, :default => false
  opt :batch_size, "Limit memory usage by process this number of report results at a time.",    :default => 50
  opt :count,      "Stop checking after this number of report results.",                        :default => 0
end

puts "Using options: #{opts.inspect}\n\n"

if defined?(Rails)
  puts "Warning: Rails is already loaded!  Please do not invoke using rails runner. Exiting with help text.\n\n"
  Trollop.educate
end

# Load rails after trollop options are set.  No one wants to wait for -h.
require File.expand_path('../config/environment', __dir__)

if opts[:dry_run]
  puts "Running in dry-run, changes will be rolled back when complete."
  ActiveRecord::Base.connection.begin_transaction(:joinable => false)

  at_exit do
    ActiveRecord::Base.connection.rollback_transaction
  end
end

start = Time.now.utc
total = 0
fixed = 0
MiqReportResult.find_each(:batch_size => opts[:batch_size]).with_index do |rr, i|
  break if opts[:count].positive? && i == opts[:count]
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
  total += 1
end

puts "Processed #{total} rows. #{fixed} were fixed. #{Time.now.utc - start} seconds"
