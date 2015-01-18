def log(msg)
  $log.info "MIQ(#{__FILE__}) #{msg}"
  puts msg
end

STORAGE_CLASSES = [
  "MiqCimInstance",
  "MiqCimAssociation",
  "MiqCimDerivedMetric",
  "MiqStorageMetric",
  "StorageMetricsMetadata",
  "OntapAggregateDerivedMetric",
  "OntapAggregateMetricsRollup",
  "OntapDiskDerivedMetric",
  "OntapDiskMetricsRollup",
  "OntapLunDerivedMetric",
  "OntapLunMetricsRollup",
  "OntapSystemDerivedMetric",
  "OntapSystemMetricsRollup",
  "OntapVolumeDerivedMetric",
  "OntapVolumeMetricsRollup"
]

begin
  log "Purging all storage data..."
  gtotal = 0
  STORAGE_CLASSES.each do |scn|
    sc = scn.constantize
    tn = sc.name.underscore.pluralize
    total = 0
    log "-- Purging table: #{tn}..."
    sc.select(:id).find_in_batches(:batch_size => 500) do |ma|
      ids = ma.collect(&:id)
      total += sc.delete_all(:id => ids)
    end
    gtotal += total
    log "-- Done. Purged #{total} records from #{tn} table."
  end
  log "All storage data purged, #{gtotal} records deleted."
rescue => err
  log err.to_s
  log err.backtrace.join("\n")
end
