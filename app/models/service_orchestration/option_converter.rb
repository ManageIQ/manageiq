class ServiceOrchestration
  # helper class to convert user dialog options to stack options understood by each manager (provider)
  class OptionConverter
    def self.get_stack_name(dialog_options)
      dialog_options['dialog_stack_name']
    end

    def self.get_template(dialog_options)
      if dialog_options['dialog_stack_template']
        OrchestrationTemplate.find(dialog_options['dialog_stack_template'])
      end
    end

    def self.get_manager(dialog_options)
      if dialog_options['dialog_stack_manager']
        ExtManagementSystem.find(dialog_options['dialog_stack_manager'])
      end
    end

    def self.get_tenant_name(dialog_options)
      dialog_options['dialog_tenant_name']
    end

    def initialize(dialog_options)
      @dialog_options = dialog_options
    end

    def stack_parameters
      params = {}
      @dialog_options.with_indifferent_access.each do |attr, val|
        if attr.start_with?('dialog_param_')
          params[attr['dialog_param_'.size..-1]] = val
        elsif attr.start_with?('password::dialog_param_')
          params[attr['password::dialog_param_'.size..-1]] = ManageIQ::Password.decrypt(val)
        end
      end
      params
    end

    def stack_create_options
      raise NotImplementedError, "stack_create_options must be implemented by a subclass"
    end

    # factory method to instantiate a provider dependent converter
    def self.get_converter(dialog_options, manager_class)
      manager_class::OrchestrationServiceOptionConverter.new(dialog_options)
    end
  end
end
