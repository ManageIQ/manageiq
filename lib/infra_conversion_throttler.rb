class InfraConversionThrottler
  def self.start_conversions
    pending_conversion_jobs.each do |ems, jobs|
      running = ems.conversion_hosts.inject(0) { |sum, ch| sum + ch.active_tasks.count }
      $log&.debug("There are currently #{running} conversion hosts running.")
      slots = (ems.miq_custom_get('Max Transformation Runners') || Settings.transformation.limits.max_concurrent_tasks_per_ems).to_i - running
      $log&.debug("The maximum number of concurrent tasks for the EMS is: #{slots}.")
      jobs.each do |job|
        eligible_hosts = ems.conversion_hosts.select(&:eligible?).sort_by { |ch| ch.active_tasks.count }

        if eligible_hosts.size > 0
          $log&.debug("The following conversion hosts are currently eligible: " + eligible_hosts.map(&:name).join(', '))
        end

        break if slots <= 0 || eligible_hosts.empty?
        job.migration_task.update_attributes!(:conversion_host => eligible_hosts.first)
        job.queue_signal(:start)
        _log.info("Pening InfraConversionJob: id=#{job.id} signaled to start")
        slots -= 1

        $log&.debug("The current number of available tasks is: #{slots}.")
      end
    end
  end

  def self.pending_conversion_jobs
    pending = InfraConversionJob.where(:state => 'waiting_to_start')
    _log.info("Pening InfraConversionJob: #{pending.count}")
    pending.group_by { |job| job.migration_task.destination_ems }
  end
end
