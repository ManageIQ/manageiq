class ManageIQ::Providers::ImageImportJob
  class Dispatcher < Job::Dispatcher
    def dispatch
      pending, = Benchmark.realtime_block(:pending_import_jobs) { pending_import_jobs }
      running, = Benchmark.realtime_block(:running_import_jobs) { running_import_jobs }
      busy_src_ids = running.flat_map { |_, dst| dst.map { |job| job.options[:src_provider_id] } }.uniq

      pending.each do |dst_id, pending_jobs|
        break if running[dst_id].present? || busy_src_ids.include?(dst_id)

        pending_job = pending_jobs.detect { |x| busy_src_ids.exclude?(x.options[:src_provider_id]) }
        next if pending_job.nil?

        busy_src_ids << pending_job.options[:src_provider_id]
        do_dispatch(pending_job)
      end
    end

    def running_import_jobs
      running_jobs.group_by { |job| job.options[:ems_id] }
    end

    def pending_import_jobs
      pending_jobs.group_by { |job| job.options[:ems_id] }
    end

    def do_dispatch(job)
      MiqQueue.put_unless_exists(
        :args        => [:start],
        :class_name  => "Job",
        :instance_id => job.id,
        :method_name => "signal",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :task_id     => job.guid,
        :zone        => job.zone
      )
    end
  end
end
