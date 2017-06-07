# Delete any records older than this:
ARCHIVE_CUTOFF = Time.now.utc - 1.month
# If true, do not delete anything; only report:
REPORT_ONLY = true

old_logger = $log
$log = VMDBLogger.new(STDOUT)
$log.level = Logger::INFO

purged = 0

# Deleting these records will cause the deletion of dependent records: Containers, Container Definitions, etc.
ENTITIES = [ContainerProject, ContainerGroup].freeze

$log.info "Searching for archived Container records older than #{ARCHIVE_CUTOFF} UTC."
if REPORT_ONLY
  $log.info "Reporting only; no rows will be deleted."
else
  $log.warn "Will delete any matching records."
end

ENTITIES.each do |entity|
  entity.where("deleted_on IS NOT NULL AND deleted_on < ?", ARCHIVE_CUTOFF).find_in_batches do |records|
    records.each do |rec|
      begin
        purged += 1
        unless REPORT_ONLY
          $log.info "Deleting archived #{entity} '#{rec.name}' (id #{rec.id})"
          rec.destroy
        end
      rescue => err
        $log.error("#{err} #{err.backtrace.join("\n")}")
      end
    end
  end
end

$log.info "Purging completed: #{REPORT_ONLY ? 'Found' : 'Purged'} #{purged} archived Container records."

$log.close
$log = old_logger
