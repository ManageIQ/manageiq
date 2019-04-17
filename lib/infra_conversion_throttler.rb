class InfraConversionThrottler
  def self.start_conversions
    pending_conversion_jobs.each do |ems, jobs|
      running = ems.conversion_hosts.inject(0) { |sum, ch| sum + ch.active_tasks.size }
      slots = (ems.miq_custom_get('Max Transformation Runners') || Settings.transformation.limits.max_concurrent_tasks_per_ems).to_i - running
      jobs.each do |job|
        eligible_hosts = ems.conversion_hosts.select(&:eligible?).sort_by { |ch| ch.active_tasks.size }
        break if slots <= 0 || eligible_hosts.empty?
        job.migration_task.update_attributes!(:conversion_host => eligible_hosts.first)
        job.queue_signal(:start)
        _log.info("Pending InfraConversionJob: id=#{job.id} signaled to start")
        slots -= 1
      end
    end
  end

  def self.pending_conversion_jobs
    pending = InfraConversionJob.where(:state => 'waiting_to_start')
    _log.info("Pending InfraConversionJob: #{pending.count}")
    pending.group_by { |job| job.migration_task.destination_ems }
  end

  def self.running_conversion_jobs
    running = InfraConversionJob.where(:state => 'running')
    _log.info("Running InfraConversionJob: #{running.count}")
    running.group_by { |job| job.migration_task.conversion_host }
  end

  def self.apply_limits
    running_conversion_jobs.each do |ch, jobs|
      number_of_jobs = ch.active_tasks.size
      cpu_limit = ch.cpu_limit || Settings.transformation.limits.cpu_limit_per_host
      network_limit = ch.network_limit || Settings.transformation.limits.network_limit_per_host
      jobs.each do |job|
        throttling_file_path = job.migration_task.options.fetch_path(:virtv2v_wrapper, 'throttling_file')
        if throttling_file_path
          limits = {
            :cpu     => cpu_limit == 'unlimited' ? cpu_limit : (cpu_limit.to_i / number_of_jobs).to_s,
            :network => network_limit == 'unlimited' ? network_limit : (network_limit.to_i / number_of_jobs).to_s
          }
          ch.apply_task_limits(throttling_file_path, limits)
        end
      end
    end
  end
end
