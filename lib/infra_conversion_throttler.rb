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

  # @return [Hash] the list of jobs in state 'running', grouped by conversion host
  def self.running_conversion_jobs
    running = InfraConversionJob.where(:state => 'running')
    _log.info("Running InfraConversionJob: #{running.count}")
    running.group_by { |job| job.migration_task.conversion_host }
  end

  # Calculate and apply the limits for all running jobs.
  # The supported limits are:
  #   - CPU per conversion host
  #   - network per conversion host
  #
  # The limits can be retrieved per conversion host or from the default setting.
  # When virt-v2v-wrapper starts the task stores the throttling file path in task.options[:virt-v2v-wrapper]['throttling_file'].
  # There is no need to adjust limits if virt-v2v-wrapper has not been called by the task.
  # The resources are evenly split between the jobs on a same conversion host.
  # There is no need to adjust limits if they have not changed.
  # Applying the limits is done via the conversion_host which handles the writing.
  def self.apply_limits
    running_conversion_jobs.each do |ch, jobs|
      number_of_jobs = jobs.size

      cpu_limit = ch.cpu_limit || Settings.transformation.limits.cpu_limit_per_host
      cpu_limit = (cpu_limit.to_i / number_of_jobs).to_s unless cpu_limit == "unlimited"

      network_limit = ch.network_limit || Settings.transformation.limits.network_limit_per_host
      network_limit = (network_limit.to_i / number_of_jobs).to_s unless network_limit == "unlimited"

      jobs.each do |job|
        migration_task = job.migration_task
        throttling_file_path = migration_task.options.fetch_path(:virtv2v_wrapper, 'throttling_file')
        next unless throttling_file_path
        limits = {
          :cpu     => cpu_limit,
          :network => network_limit
        }
        unless migration_task.options[:virtv2v_limits] == limits
          ch.apply_task_limits(throttling_file_path, limits)
          migration_task.update_options(:virtv2v_limits => limits)
        end
      end
    end
  end
end
