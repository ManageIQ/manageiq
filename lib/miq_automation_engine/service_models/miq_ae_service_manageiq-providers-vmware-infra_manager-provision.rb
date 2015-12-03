module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Provision < MiqAeServiceMiqProvision
    def eligible_customization_specs
      sysprep = options[:sysprep_enabled]
      options[:sysprep_enabled] = %w(fields Specification)
      wrap_results(object_send(:eligible_resources, :customization_specs)).tap do
        options[:sysprep_enabled] = sysprep
      end
    end
  end
end
