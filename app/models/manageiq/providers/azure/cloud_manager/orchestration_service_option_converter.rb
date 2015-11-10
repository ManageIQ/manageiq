module ManageIQ::Providers
  class Azure::CloudManager::OrchestrationServiceOptionConverter < ::ServiceOrchestration::OptionConverter
    def stack_create_options
      {
        :parameters     => stack_parameters,
        :resource_group => @dialog_options['dialog_resource_group'] || @dialog_options['dialog_new_resource_group'],
        :mode           => @dialog_options['dialog_deploy_mode']
      }
    end
  end
end
