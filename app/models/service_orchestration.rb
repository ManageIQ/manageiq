class ServiceOrchestration < Service
  include ServiceOrchestrationMixin

  # options to create the stack: read from DB or build from dialog
  def stack_options
    @stack_options ||= get_option(:create_options) || build_stack_create_options
  end

  # override existing stack options (most likely from dialog)
  def stack_options=(opts)
    @stack_options = opts
    save_option(:create_options, opts)
  end

  # options to update the stack: read from DB. Cannot directly read from dialog
  def update_options
    @update_options ||= get_option(:update_options)
  end

  # must explicitly call this to set the options for update since they cannot be directly read from dialog
  def update_options=(opts)
    @update_options = opts
    save_option(:update_options, opts)
  end

  # read from DB or parse from dialog
  def stack_name
    @stack_name ||= get_option(:stack_name) || OptionConverter.get_stack_name(options[:dialog] || {})
  end

  # override existing stack name (most likely from dialog)
  def stack_name=(stname)
    @stack_name = stname
    save_option(:stack_name, stname)
  end

  #
  # deprecated
  #
  def stack_ems_ref
    orchestration_stack.try(:ems_ref)
  end

  def orchestration_stack_status
    return "check_status_failed", "stack has not been deployed" unless orchestration_stack

    orchestration_stack.raw_status.normalized_status
  rescue MiqException::MiqOrchestrationStackNotExistError, MiqException::MiqOrchestrationStatusError => err
    # naming convention requires status to end with "failed"
    ["check_status_failed", err.message]
  end

  def deploy_orchestration_stack
    @orchestration_stack =
      OrchestrationStack.create_stack(orchestration_manager, stack_name, orchestration_template, stack_options)
    add_resource(@orchestration_stack)
    @orchestration_stack
  ensure
    # create options may never be saved before unless they were overridden
    save_create_options
  end

  def update_orchestration_stack
    # use orchestration_template from service_template, which may be different from existing orchestration_template
    orchestration_stack.raw_update_stack(
      :template   => service_template.orchestration_template.content,
      :parameters => update_options[:parameters]
    )
  end

  def orchestration_stack
    @orchestration_stack ||= service_resources.find { |sr| sr.resource.kind_of?(OrchestrationStack) }.try(:resource)
  end

  def build_stack_options_from_dialog(dialog_options)
    tenant_name = OptionConverter.get_tenant_name(dialog_options)
    tenant_option = tenant_name ? {:tenant_name => tenant_name} : {}

    converter = OptionConverter.get_converter(dialog_options || {}, orchestration_manager.class)
    converter.stack_create_options.merge(tenant_option)
  end

  private

  def build_stack_create_options
    # manager from dialog_options overrides the one copied from service_template
    dialog_options = options[:dialog] || {}
    manager_from_dialog = OptionConverter.get_manager(dialog_options)
    self.orchestration_manager = manager_from_dialog if manager_from_dialog
    raise "orchestration manager was not set" if orchestration_manager.nil?

    # orchestration template from dialog_options overrides the one copied from service_template
    template_from_dialog = OptionConverter.get_template(dialog_options)
    self.orchestration_template = template_from_dialog if template_from_dialog

    build_stack_options_from_dialog(options[:dialog])
  end

  def save_create_options
    options.merge!(:stack_name     => stack_name,
                   :create_options => dup_and_process_password(stack_options))
    save!
  end

  def dup_and_process_password(opts, encrypt = :encrypt)
    return opts unless opts.kind_of?(Hash)

    opts_dump = opts.deep_dup
    parameters = opts_dump[:parameters] || {}
    proc = MiqPassword.method(encrypt)
    parameters.each { |key, val| parameters[key] = proc.call(val) if key.downcase =~ /password/ }

    opts_dump
  end

  def get_option(option_name)
    dup_and_process_password(options[option_name], :decrypt) if options[option_name]
  end

  def save_option(option_name, val)
    options.merge!(option_name => dup_and_process_password(val, :encrypt))
    save!
  end
end
