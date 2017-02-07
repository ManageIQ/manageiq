module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Redhat_InfraManager < MiqAeServiceEmsInfra
    include MiqAeServiceEmsOperationsMixin

    expose :validate_import_vm

    def import_vm(source_vm_id, target_params, options = {})
      sync_or_async_ems_operation(options[:sync], "import_vm", [source_vm_id, target_params])
    end
  end
end
