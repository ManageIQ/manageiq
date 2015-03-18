class ServiceOrchestration
  class OptionConverterOpenstack < OptionConverter
    def stack_create_options
      on_failure = @dialog_options['dialog_stack_onfailure']
      timeout = @dialog_options['dialog_stack_timeout']
      stack_options = {:parameters => stack_parameters, :disable_rollback => on_failure != 'ROLLBACK'}
      stack_options[:timeout_mins] = (timeout.to_i + 30) / 60 unless timeout.blank?

      stack_options
    end
  end
end
