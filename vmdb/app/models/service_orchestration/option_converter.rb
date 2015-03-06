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

    def initialize(dialog_options)
      @dialog_options = dialog_options
    end

    def stack_parameters
      params = {}
      @dialog_options.each do |attr, val|
        if attr.start_with?('dialog_param_')
          params[attr['dialog_param_'.size..-1]] = val
        elsif attr.start_with?('password::dialog_param_')
          params[attr['password::dialog_param_'.size..-1]] = MiqPassword.decrypt(val)
        end
      end
      params
    end

    def stack_create_options
      raise NotImplementedError, "stack_create_options must be implemented by a subclass"
    end

    # factory method to instantiate a provider dependent converter
    def self.get_converter(dialog_options, manager_class_name)
      class_name = "ServiceOrchestration::OptionConverter#{manager_class_name.match(/Ems(.*)/)[1]}"
      class_name.constantize.new(dialog_options)
    end
  end
end
