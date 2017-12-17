class ServiceContainerTemplate < ServiceGeneric
  delegate :container_template, :container_manager, :to => :service_template, :allow_nil => true

  # A chance for taking options from automate script to override options from a service dialog
  def preprocess(action, new_options = {})
    return unless action == ResourceAction::PROVISION

    unless new_options.blank?
      _log.info("Override with new options:")
      $log.log_hashes(new_options)
    end

    save_action_options(action, new_options)
  end

  def execute(action)
    return unless action == ResourceAction::PROVISION

    opts = get_action_options(action)

    _log.info("Container template provisioning with options:")
    $log.log_hashes(opts)

    params = process_parameters(opts[:parameters])
    stack_klass = "#{container_manager.class.name}::OrchestrationStack".constantize
    new_stack = stack_klass.create_stack(container_template, params, opts[:container_project_name])
    _log.info("Container provisioning with template ID: [#{id}] name:[#{name}] was initiated.")

    add_resource!(new_stack, :name => action)
  end

  def check_completed(action)
    return [true, 'not supported'] unless action == ResourceAction::PROVISION

    status, reason = stack.raw_status.normalized_status
    done    = status != 'transient'
    message = status == 'create_complete' ? nil : reason
    [done, message]
  end

  def refresh(action)
  end

  def check_refreshed(_action)
    [true, nil]
  end

  def on_error(action)
    _log.info("on_error called for service: [#{name}] action: [#{action}]")
  end

  def stack
    service_resources.find_by(:name => ResourceAction::PROVISION, :resource_type => 'OrchestrationStack').try(:resource)
  end

  private

  def process_parameters(inputs)
    params = container_template.container_template_parameters.to_a
    inputs.each do |key, value|
      match = params.find { |p| p.name == key.to_s }
      match.value = value if match
    end
    params
  end

  def get_action_options(action)
    options[action_option_key(action)].deep_dup
  end

  def save_action_options(action, overrides)
    return unless action == ResourceAction::PROVISION

    action_options = {
      :container_project_name => project_name(overrides),
      :parameters             => parameters_from_dialog.with_indifferent_access.merge(overrides)
    }

    options[action_option_key(action)] = action_options
    save!
  end

  def action_option_key(action)
    "#{action.downcase}_options".to_sym
  end

  def parameters_from_dialog
    params =
      options[:dialog].each_with_object({}) do |(attr, val), obj|
        var_key = attr.sub(/dialog_param_/, '')
        obj[var_key] = val unless var_key == attr
      end

    params.blank? ? {} : params
  end

  def project_name(overrides)
    # :dialog option should specify the project name, either an existing project or a new project name
    dialog_options = options[:dialog]
    existing_name = overrides.delete(:existing_project_name) || dialog_options['dialog_existing_project_name']
    new_project_name = overrides.delete(:new_project_name) || dialog_options['dialog_new_project_name']

    create_project(new_project_name) if new_project_name
    project_name = new_project_name || existing_name

    raise _("A project is required for the container template provisioning") unless project_name
    project_name
  end

  def create_project(name)
    container_manager.create_project(:metadata => {:name => name})
  end
end
