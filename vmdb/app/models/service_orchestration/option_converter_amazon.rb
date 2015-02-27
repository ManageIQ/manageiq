class ServiceOrchestration
  class OptionConverterAmazon < OptionConverter
    def stack_create_options
      on_failure = @dialog_options['dialog_stack_onfailure']
      timeout = @dialog_options['dialog_stack_timeout']
      stack_options = {:parameters => stack_parameters, :disable_rollback => on_failure != 'ROLLBACK'}
      stack_options[:timeout] = timeout.to_i unless timeout.blank?

      stack_options
    end
  end
end
