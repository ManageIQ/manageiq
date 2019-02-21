class InfraConversionThrottler
  DEFAULT_EMS_MAX_RUNNERS = 10

  def self.start_conversions
    pending_conversion_jobs.each do |ems, jobs|
      running = ems.conversion_hosts.inject(0) { |sum, ch| sum + ch.active_tasks.size }
      slots = (ems.miq_custom_get('Max Transformation Runners') || DEFAULT_EMS_MAX_RUNNERS).to_i - running
      jobs.each do |job|
        eligible_hosts = ems.conversion_hosts.select(&:eligible?).sort_by { |ch| ch.active_tasks.size }
        break if slots <= 0 || eligible_hosts.empty?
        job.migration_task.update_attributes!(:conversion_host => eligible_hosts.first)
        job.queue_signal(:start)
        _log.info("Pening InfraConversionJob: id=#{job.id} signaled to start")
        slots -= 1
      end
    end
  end

  def self.pending_conversion_jobs
    pending = InfraConversionJob.where(:state => 'waiting_to_start')
    _log.info("Pening InfraConversionJob: #{pending.count}")
    pending.group_by { |job| job.migration_task.destination_ems }
  end
end
