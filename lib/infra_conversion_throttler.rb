class InfraConversionThrottler
  include Vmdb::Logging

  def self.start_conversions
    _log.debug("InfraConversionThrottler.start_conversions")
    pending_conversion_jobs.each do |ems, jobs|
      _log.debug("- EMS: #{ems.name}")
      _log.debug("-- Number of pending jobs: #{jobs.size}")
      running = ems.conversion_hosts.inject(0) { |sum, ch| sum + ch.active_tasks.count }
      _log.debug("-- Currently running jobs in EMS: #{running}")
      slots = (ems.miq_custom_get('MaxTransformationRunners') || Settings.transformation.limits.max_concurrent_tasks_per_ems).to_i - running

      jobs.each do |job|
        vm_name = job.migration_task.source.name

        preflight_check = job.migration_task.preflight_check
        if preflight_check[:status] == 'Error'
          _log.error("Preflight check for #{vm_name} has failed: #{preflight_check[:message]}. Discarding.")
          job.abort_conversion(preflight_check[:message], 'error')
          next
        end

        if slots <= 0
          _log.debug("-- No available slot in EMS. Skipping.")
          next
        end
        _log.debug("-- Available slots in EMS: #{slots}")
        _log.debug("- Looking for a conversion host for task for #{vm_name}")

        eligibility = job.migration_task.warm_migration? ? :warm_migration_eligible? : :eligible?
        eligible_hosts = ems.conversion_hosts.select(&eligibility).sort_by { |ch| ch.active_tasks.count }

        if eligible_hosts.empty?
          _log.debug("-- No eligible conversion host for task for '#{vm_name}'")
          break
        end

        _log.debug("-- Eligible conversion hosts:")
        eligible_hosts.each do |eh|
          max_tasks = eh.max_concurrent_tasks || Settings.transformation.limits.max_concurrent_tasks_per_conversion_host
          _log.debug("--- #{eh.name} [#{eh.active_tasks.count}/#{max_tasks}]")
        end

        eligible_host = eligible_hosts.first
        _log.debug("-- Associating  #{eligible_host.name} to the task for '#{vm_name}'.")
        job.migration_task.update!(:conversion_host => eligible_host)
        job.migration_task.update_options(:conversion_host_name => eligible_host.name)

        _log.debug("-- Queuing :start signal for the job for '#{vm_name}': current state is '#{job.state}'.")
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
    running = InfraConversionJob.where.not(:state => ['waiting_to_start', 'finished'])
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
      if ch.nil?
        bad_tasks = jobs.map { |j| j.migration_task&.source&.name }.compact.join(', ')
        _log.error("The following migrating VMs don't have a conversion host: #{bad_tasks}.")
        next
      end

      number_of_jobs = jobs.size

      cpu_limit = ch.cpu_limit || Settings.transformation.limits.cpu_limit_per_host
      cpu_limit = (cpu_limit.to_i / number_of_jobs).to_s unless cpu_limit == "unlimited"

      network_limit = ch.network_limit || Settings.transformation.limits.network_limit_per_host
      network_limit = (network_limit.to_i / number_of_jobs).to_s unless network_limit == "unlimited"

      jobs.each do |job|
        migration_task = job.migration_task
        next unless migration_task.virtv2v_running?
        next unless migration_task.options.fetch_path(:virtv2v_wrapper, 'throttling_file')

        limits = {
          :cpu     => cpu_limit,
          :network => network_limit
        }
        unless migration_task.options[:virtv2v_limits] == limits
          ch.apply_task_limits(migration_task.options.fetch_path(:virtv2v_wrapper, 'throttling_file'), limits)
          migration_task.update_options(:virtv2v_limits => limits)
        end
      end
    end
  end
end
