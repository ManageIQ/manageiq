class InfraConversionThrottler
  DEFAULT_EMS_MAX_RUNNERS = 10

  def self.start_tasks
    pending = ManageIQ::Providers::InfraConversionJob.where(:state => 'waiting_to_start')
    return if pending.empty?
    by_ems = pending.sort_by(&:created_on).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |job, hash|
      task = job.migration_task
      hash[task.destination_ems].append(job)
    end
    by_ems.each do |ems, jobs|
      running = ems.conversion_hosts.inject(0) { |sum, ch| sum + ch.active_tasks.size }
      slots = (ems.miq_custom_get('Max Transformation Runners') || DEFAULT_EMS_MAX_RUNNERS) - running
      jobs.each do |job|
        task = job.migration_task
        eligible_hosts = ems.conversion_hosts.select(&:eligible?).sort_by { |ch| ch.active_tasks.size }
        break if slots <= 0 || eligible_hosts.empty?
        begin
          task.conversion_host = eligible_hosts.first
          task.save!
          job.queue_signal(:start)
          slots -= 1
        rescue StandardError => err
          _log.error("Migration task id=#{task.id} error: #{err}")
          _log.log_backtrace(err)
        end
      end
    end
  end

  def self.tune_tasks
    # This can be triggered either by a timer or by events
    #   - a conversion job started/ended
    #   - arrival of an active conversion_host's metrics (cpu, memory, network)
    #
    # We can have each job.poll_conversion to record running parameters that this method can act on
    # Metrics of conversion_host can be from
    #   - existing MIQ metrics of the Vm or the Host or the EMS
    #   - implemend a on-demand e.g. conversion_host.get_loading which ssh into host to probe
    #
  end
end
