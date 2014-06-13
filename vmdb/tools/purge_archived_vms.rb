# Delete any records older than this:
ARCHIVE_CUTOFF = Time.now.utc - 1.month
# If true, do not delete anything; only report:
REPORT_ONLY = true

old_logger = $log
$log = VMDBLogger.new(STDOUT)
$log.level = Logger::INFO

archived, not_archived = 0, 0

$log.info "Searching for archived VMs older than #{ARCHIVE_CUTOFF} UTC."
if REPORT_ONLY
  $log.info "Reporting only; no rows will be deleted."
else
  $log.warn "Will delete any matching records." unless REPORT_ONLY
end

Vm.find_in_batches(:conditions => ["vms.updated_on IS NULL OR vms.updated_on < ?", ARCHIVE_CUTOFF], :include => [:ext_management_system, :storage]) do |vms|
  vms.each do |vm|
    begin
      if vm.archived?
        archived += 1
        unless REPORT_ONLY
          $log.info "Deleting archived VM '#{vm.name}' (id #{vm.id})"
          vm.destroy
        end
      else
        not_archived += 1
      end
    rescue => err
      $log.error("#{err} #{err.backtrace.join("\n")}")
    end
  end
end

$log.info "Completed purging archived VMs. #{REPORT_ONLY ? 'Found' : 'Purged'} #{archived} archived VMs. There were #{not_archived} non-archived VMs."

$log.close
$log = old_logger
