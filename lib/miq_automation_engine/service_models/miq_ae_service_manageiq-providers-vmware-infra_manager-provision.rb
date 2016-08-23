module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Provision < MiqAeServiceMiqProvision
    expose_eligible_resources :storage_profiles

    def set_customization_spec(name = nil, override = false)
      object_send(:set_customization_spec, name, override)
    end

    def eligible_customization_specs
      sysprep = options[:sysprep_enabled]
      options[:sysprep_enabled] = %w(fields Specification)
      wrap_results(object_send(:eligible_resources, :customization_specs)).tap do
        options[:sysprep_enabled] = sysprep
      end
    end
  end
end
