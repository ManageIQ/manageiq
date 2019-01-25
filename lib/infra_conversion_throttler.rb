class InfraConversionThrottler
  DEFAULT_EMS_MAX_RUNNERS = 10

  def self.assign_to_tasks
    pending = ManageIQ::Providers::InfraConversionJob.where(:state => 'waiting_to_start')
    return if pending.empty?
    by_ems = pending.sort_by(&:created_on).each_with_object({}) do |job, hash|
      task = job.migration_task
      hash[task.destination_ems] = hash[task.destination_ems] || []
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
end
