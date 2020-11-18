module MiqServer::AtStartup
  extend ActiveSupport::Concern
  include Vmdb::Logging

  module ClassMethods
    def startup!
      log_managed_entities
      write_systemd_unit_files
      clean_all_workers
      clean_dequeued_messages
      purge_report_results
    end

    def log_managed_entities
      region = MiqRegion.my_region
      prefix = "#{_log.prefix} Region: [#{region.region}], name: [#{region.name}]"
      log_under_management(prefix)
      log_not_under_management(prefix)
    end

    def write_systemd_unit_files
      return unless MiqEnvironment::Command.supports_systemd?

      _log.info("Writing Systemd unit files...")
      MiqWorkerType.worker_class_names.each do |class_name|
        worker_klass = class_name.safe_constantize
        worker_klass.ensure_systemd_files if worker_klass&.systemd_worker?
      rescue => err
        _log.warn("Failed to write systemd service files: #{err}")
        _log.log_backtrace(err)
      end
      _log.info("Writing Systemd unit files...Complete")
    end

    # Delete and Kill all workers that were running previously
    def clean_all_workers
      _log.info("Cleaning up all workers...")
      MiqWorker.server_scope.each do |w|
        Process.kill(9, w.pid) if w.pid && w.is_alive? rescue nil
        w.destroy
      end
      _log.info("Cleaning up all workers...Complete")
    end

    def clean_dequeued_messages
      _log.info("Cleaning up dequeued messages...")
      MiqQueue.where(:state => MiqQueue::STATE_DEQUEUE).each do |message|
        if message.handler.nil?
          _log.warn("Cleaning message in dequeue state without worker: #{MiqQueue.format_full_log_msg(message)}")
        else
          handler_server = message.handler            if message.handler.kind_of?(MiqServer)
          handler_server = message.handler.miq_server if message.handler.kind_of?(MiqWorker)
          next unless handler_server == MiqServer.my_server

          _log.warn("Cleaning message: #{MiqQueue.format_full_log_msg(message)}")
        end
        if message.method_name == "shutdown_and_exit"
          message.delete
        else
          message.update(:state => MiqQueue::STATE_ERROR) rescue nil
        end
      end
      _log.info("Cleaning up dequeued messages...Complete")
    end

    def purge_report_results
      _log.info("Purging adhoc report results...")
      MiqReportResult.purge_for_all_users
      _log.info("Purging adhoc report results...Complete")
    end

    private

    def log_under_management(prefix)
      total_vms, total_hosts, total_sockets = managed_resources.values_at(:vms, :hosts, :aggregate_physical_cpus)
      $log.info("#{prefix}, Under Management: VMs: [#{total_vms}], Hosts: [#{total_hosts}], Sockets: [#{total_sockets}]")
    end

    def log_not_under_management(prefix)
      vms, hosts, sockets = unmanaged_resources.values_at(:vms, :hosts, :aggregate_physical_cpus)
      $log.info("#{prefix}, Not Under Management: VMs: [#{vms}], Hosts: [#{hosts}], Sockets: [#{sockets}]")
    end
  end
end
