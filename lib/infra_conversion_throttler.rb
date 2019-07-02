class InfraConversionThrottler
  include Vmdb::Logging

  def self.start_conversions
    _log.debug("InfraConversionThrottler.start_conversions")
    pending_conversion_jobs.each do |ems, jobs|
      _log.debug("- EMS: #{ems.name}")
      _log.debug("-- Number of pending jobs: #{jobs.size}")
      running = ems.conversion_hosts.inject(0) { |sum, ch| sum + ch.active_tasks.count }
      _log.debug("-- Currently running jobs in EMS: #{running}")
      slots = (ems.miq_custom_get('Max Transformation Runners') || Settings.transformation.limits.max_concurrent_tasks_per_ems).to_i - running

      if slots <= 0
        _log.debug("-- No available slot in EMS. Stopping.")
        next
      end
      _log.debug("-- Available slots in EMS: #{slots}")

      jobs.each do |job|
        vm_name = job.migration_task.source.name
        _log.debug("- Looking for a conversion host for task for #{vm_name}")

        eligible_hosts = ems.conversion_hosts.select(&:eligible?).sort_by { |ch| ch.active_tasks.count }
        if eligible_hosts.empty?
          _log.debug("-- No eligible conversion host for task for '#{vm_name}'")
          break
        end

        _log.debug("-- Eligible conversion hosts:")
        eligible_hosts.each do |eh|
          max_tasks = eh.max_concurrent_tasks || Settings.transformation.limits.max_concurrent_tasks_per_host
          _log.debug("--- #{eh.name} [#{eh.active_tasks.count}/#{max_tasks}]")
        end

        eligible_host = eligible_hosts.first
        _log.debug("-- Associating  #{eligible_host.name} to the task for '#{vm_name}'.")
        job.migration_task.update_attributes!(:conversion_host => eligible_hosts.first)

        _log.debug("-- Queuing :start signal for the job for '#{vm_name}': current state is '#{job.state}'.")
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
