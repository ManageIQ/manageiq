module MiqServer::AtStartup
  extend ActiveSupport::Concern
  include Vmdb::Logging

  module ClassMethods
    def log_managed_entities
      region = MiqRegion.my_region
      prefix = "#{_log.prefix} Region: [#{region.region}], name: [#{region.name}]"
      log_under_management(prefix)
      log_not_under_management(prefix)
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
      total_vms     = 0
      total_hosts   = 0
      total_sockets = 0

      ExtManagementSystem.all.each do |e|
        vms     = e.all_vms_and_templates.count
        hosts   = e.all_hosts.count
        sockets = e.aggregate_physical_cpus
        $log.info("#{prefix}, EMS: [#{e.id}], Name: [#{e.name}], IP Address: [#{e.ipaddress}], Hostname: [#{e.hostname}], VMs: [#{vms}], Hosts: [#{hosts}], Sockets: [#{sockets}]")

        total_vms += vms
        total_hosts += hosts
        total_sockets += sockets
      end
      $log.info("#{prefix}, Under Management: VMs: [#{total_vms}], Hosts: [#{total_hosts}], Sockets: [#{total_sockets}]")
    end

    def log_not_under_management(prefix)
      hosts_objs = Host.where(:ems_id => nil)
      hosts      = hosts_objs.count
      vms        = VmOrTemplate.where(:ems_id => nil).count
      sockets    = MiqRegion.my_region.aggregate_physical_cpus(hosts_objs)
      $log.info("#{prefix}, Not Under Management: VMs: [#{vms}], Hosts: [#{hosts}], Sockets: [#{sockets}]")
    end
  end
end