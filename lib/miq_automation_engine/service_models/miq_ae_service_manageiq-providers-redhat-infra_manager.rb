module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Redhat_InfraManager < MiqAeServiceEmsInfra
    expose :validate_import_vm
    expose :submit_import_vm
    expose :submit_configure_imported_vm_networks
  end
end
