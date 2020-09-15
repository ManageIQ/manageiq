class ServiceOvfTemplate < ServiceGeneric
  delegate :template, :manager, :to => :service_template, :allow_nil => true

  # A chance for taking options from automate script to override options from a service dialog
  def preprocess(action, new_options = {})
    return unless action == ResourceAction::PROVISION

    if new_options.present?
      _log.info("Override with new options:")
      $log.log_hashes(new_options)
    end

    save_action_options(action, new_options)
  end

  def execute(action)
    return unless action == ResourceAction::PROVISION

    library_item_deploy_queue
  end

  def library_item_deploy_queue
    task_options = {:action => "Deploying VMware Content Library Item", :userid => "system"}
    queue_options = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "library_item_deploy",
      :args        => {},
      :role        => "ems_operations",
      :queue_name  => manager.queue_name_for_ems_operations,
      :zone        => manager.my_zone
    }

    task_id = MiqTask.generic_action_with_callback(task_options, queue_options)
    task = MiqTask.wait_for_taskid(task_id)
    raise task.message unless task.status_ok?
  end

  def library_item_deploy(_options)
    _log.info("OVF template provisioning with template ID: [#{template.id}] name:[#{template.name}] was initiated.")
    opts = provision_options
    _log.info("VMware Content Library OVF Tempalte provisioning with options:")
    $log.log_hashes(opts)

    @orchestration_stack = ManageIQ::Providers::Vmware::InfraManager::OrchestrationStack.create_stack(template, opts)
    add_resource!(@orchestration_stack)
  end

  def check_completed(action)
    return [true, 'not supported'] unless action == ResourceAction::PROVISION

    status, reason = orchestration_stack.raw_status.normalized_status
    done    = status != 'transient'
    message = status == 'create_complete' ? nil : reason
    [done, message]
  rescue MiqException::MiqOrchestrationStackNotExistError, MiqException::MiqOrchestrationStatusError => err
    [true, err.message] # consider done with an error when exception is caught
  end

  def refresh(_action)
    EmsRefresh.queue_refresh(refresh_target) if deploy_response.dig("value", "succeeded")
  end

  def check_refreshed(_action)
    return [true, nil] unless deploy_response.dig("value", "succeeded")

    vm = find_destination_in_vmdb
    if vm
      orchestration_stack.resources.first.update(:name => vm.name)
      [true, nil]
    else
      [false, nil]
    end
  end

  def refresh_target
    target_folder || target_host || target_resource_pool
  end

  def on_error(action)
    _log.info("on_error called for service: [#{name}] action: [#{action}]")
  end

  def orchestration_stack
    @orchestration_stack ||= service_resources.find { |sr| sr.resource.kind_of?(OrchestrationStack) }.try(:resource)
  end

  private

  def deploy_response
    @deploy_response ||= JSON.parse(orchestration_stack.outputs.first.value).tap do |r|
      update(:options => options.merge(:deploy_response => r))
    end
  end

  def find_destination_in_vmdb
    vm_model_class.find_by(:ems_id => manager.id, :ems_ref => deploy_response.dig("value", "resource_id", "id"))
  end

  def vm_model_class
    manager.class::Vm
  end

  def target_folder
    @target_folder ||= EmsFolder.find_by(:id => provision_options[:ems_folder_id])
  end

  def target_host
    @target_host ||= Host.find_by(:id => provision_options[:host_id])
  end

  def target_resource_pool
    @target_resource_pool ||= ResourcePool.find_by(:id => provision_options[:resource_pool_id])
  end

  def get_action_options(action)
    options[action_option_key(action)]
  end

  def provision_options
    @provision_options ||= get_action_options(ResourceAction::PROVISION)
  end

  def save_action_options(action, overrides)
    return unless action == ResourceAction::PROVISION

    action_options = options.fetch_path(:config_info, action.downcase.to_sym).with_indifferent_access
    action_options.deep_merge!(parse_dialog_options)
    action_options.deep_merge!(overrides)

    options[action_option_key(action)] = action_options
    save!
  end

  def parse_dialog_options
    dialog_options = options[:dialog] || {}
    options = {:vm_name => dialog_options['dialog_vm_name']}
    options[:accept_all_EULA] = dialog_options['dialog_accept_all_EULA'] == 't'

    %w[resource_pool ems_folder host].each do |r|
      options["#{r}_id".to_sym] = dialog_options["dialog_#{r}"].split.first.to_i if dialog_options["dialog_#{r}"].present?
    end
    options
  end

  def action_option_key(action)
    "#{action.downcase}_options".to_sym
  end
end
