#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

# Delete any records older than this:
ARCHIVE_CUTOFF = Time.now.utc - 1.month
# If true, do not delete anything; only report:
REPORT_ONLY = ActiveModel::Type::Boolean.new.cast(ENV.fetch("REPORT_ONLY", true))

old_logger = $log
$log = VMDBLogger.new(STDOUT)
$log.level = Logger::INFO

query = Vm.where("updated_on < ? or updated_on IS NULL", ARCHIVE_CUTOFF)
archived = 0

$log.info("Searching for archived VMs older than #{ARCHIVE_CUTOFF} UTC.")
$log.info("Expecting to prune #{query.archived.count} of the #{query.count} older vms")
if REPORT_ONLY
  $log.info("Reporting only; no rows will be deleted.")
else
  $log.warn("Will delete any matching records.")
end

query.archived.find_in_batches do |vms|
  vms.each do |vm|
    begin
      archived += 1
      unless REPORT_ONLY
        $log.info("Deleting archived VM '#{vm.name}' (id #{vm.id})")
        vm.destroy
      end
    rescue => err
      $log.log_backtrace(err)
    end
  end
end

$log.info("Completed purging archived VMs. #{REPORT_ONLY ? 'Found' : 'Purged'} #{archived} archived VMs.")
$log.info("To cleanup archived VMs re-run with REPORT_ONLY=false #{$PROGRAM_NAME}")

$log.close
$log = old_logger
