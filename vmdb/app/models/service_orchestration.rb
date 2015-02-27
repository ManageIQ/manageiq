class ServiceOrchestration < Service
  include ServiceOrchestrationMixin

  attr_writer :stack_options  # this will override all existing stack options
  attr_writer :stack_name

  def stack_options
    @stack_options ||= build_stack_options
  end

  def stack_name
    @stack_name ||= OptionConverter.get_stack_name(options[:dialog] || {})
  end

  def orchestration_stack_status
    orchestration_manager.stack_status(stack_name)
  rescue MiqException::MiqOrchestrationStatusError => err
    # naming convention requires status to end with "failed"
    return "check_status_failed", err.message
  end

  def deploy_orchestration_stack
    save_stack_options
    orchestration_manager.stack_create(stack_name, orchestration_template, stack_options)
    nil  # if no exception
  rescue MiqException::MiqOrchestrationProvisionError => err
    err.message
  end

  private

  def build_stack_options
    # manager from dialog_options overrides the one copied from service_template
    manager_from_dialog = OptionConverter.get_manager(options[:dialog] || {})
    self.orchestration_manager = manager_from_dialog if manager_from_dialog
    raise "orchestration manager was not set" if orchestration_manager.nil?

    # orchestration template from dialog_options overrides the one copied from service_template
    template_from_dialog = OptionConverter.get_template(options[:dialog] || {})
    self.orchestration_template = template_from_dialog if template_from_dialog

    converter = OptionConverter.get_converter(options[:dialog] || {}, orchestration_manager.class.name)
    converter.stack_create_options
  end

  def save_stack_options
    options_dump = stack_options.dup
    parameters = options_dump[:parameters] || {}
    parameters.each { |key, val| parameters[key] = MiqPassword.encrypt(val) if key.downcase =~ /password/ }

    self.options = options.merge(:manager_id     => orchestration_manager.id,
                                 :template_id    => orchestration_template.id,
                                 :create_options => options_dump)
    save!
  end
end
