module MiqAeMethodService
  class MiqAeServiceVm < MiqAeServiceVmOrTemplate
    def remote_console_url=(url)
      object_send(:remote_console_url=, url, MiqAeEngine::DrbRemoteInvoker.workspace.ae_user.id)
    end

    def add_to_service(service)
      raise ArgumentError, "service must be a MiqAeServiceService" unless service.kind_of?(MiqAeMethodService::MiqAeServiceService)
      ar_method { wrap_results(Service.find_by(:id => service.id).add_resource!(@object)) }
    end

    def remove_from_service
      ar_method { wrap_results(@object.direct_service.try(:remove_resource, @object)) }
    end

    def create_snapshot(name, desc = nil, memory = false)
      snapshot_operation(:create_snapshot, :name => name, :description => desc, :memory => !!memory)
    end

    def remove_all_snapshots
      snapshot_operation(:remove_all_snapshots)
    end

    def remove_snapshot(snapshot_id)
      snapshot_operation(:remove_snapshot, :snap_selected => snapshot_id)
    end

    def revert_to_snapshot(snapshot_id)
      snapshot_operation(:revert_to_snapshot, :snap_selected => snapshot_id)
    end

    def snapshot_operation(task, options = {})
      raise "#{task} operation not supported for #{self.class.name}" unless object_send(:supports_snapshots?)

      options[:ids]  = [id]
      options[:task] = task.to_s
      Vm.process_tasks(options)
    end
  end
end
