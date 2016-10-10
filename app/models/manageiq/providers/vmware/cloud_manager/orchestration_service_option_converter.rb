module ManageIQ::Providers
  class Vmware::CloudManager::OrchestrationServiceOptionConverter < ::ServiceOrchestration::OptionConverter
    def stack_create_options
      {
        :deploy  => stack_parameters['deploy'] == 't',
        :powerOn => stack_parameters['powerOn'] == 't',
        :vdc_id  => @dialog_options['dialog_availability_zone']
      }
    end
  end
end
