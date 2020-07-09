class MiqProvisionRequestTemplate < MiqProvisionRequest
  def create_tasks_for_service(service_task, parent_svc)
    template_service_resource = ServiceResource.find_by(:id => service_task.options[:service_resource_id])
    scaling_min = number_of_vms(service_task, parent_svc, template_service_resource)
    scaling_min ||= template_service_resource.try(:scaling_min) || 1

    _log.info("create_tasks_for_service ID #{service_task.id} SCALING : #{scaling_min}")
    scaling_min.times.collect do |idx|
      create_request_task(idx) do |req_task|
        req_task.miq_request_id = service_task.miq_request.id
        req_task.userid         = service_task.userid

        task_options     = req_task.options.merge(service_options(parent_svc, template_service_resource))
        task_options     = task_options.merge(owner_options(service_task))
        req_task.options = task_options
      end
    end
  end

  def request_task_class
    MiqProvision
  end

  def post_create(_auto_approve)
    update(:description => "Miq Provision Request Template for #{source.name}")
    self
  end

  def service_template_resource_copy
    dup.tap(&:save!)
  end

  def execute
    # Should not be called.
    raise _("Provision Request Templates do not support the execute method.")
  end

  private

  def service_options(parent_svc, template_service_resource)
    {
      :miq_force_unique_name    => [true, 1],
      :service_guid             => parent_svc.guid,
      :service_resource_id      => template_service_resource.id,
      :service_template_request => false
    }
  end

  # NOTE: for services, the requester is the owner
  def owner_options(service_task)
    user = User.lookup_by_userid(service_task.userid)
    return {} if user.nil?

    {
      :requester_group  => service_task.options[:requester_group],
      :owner_email      => user.email,
      :owner_group      => service_task.options[:requester_group],
      :owner_first_name => user.first_name,
      :owner_last_name  => user.last_name
    }
  end

  def number_of_vms(service_task, parent_svc, template_service_resource)
    vm_count = nil
    if template_service_resource
      parent_task = get_parent_task(service_task)
      root_svc = get_root_svc(parent_svc)
      value = number_of_vms_from_dialog(root_svc, parent_task) if root_svc && parent_task
      vm_count = value.to_i unless value.blank?
      resource = template_service_resource.resource
      vm_count ||= resource.get_option(:number_of_vms) if resource.respond_to?(:get_option)
    end
    vm_count
  end

  def get_root_svc(parent_svc)
    return nil unless parent_svc
    parent_svc.parent ? parent_svc.parent : parent_svc
  end

  def get_parent_task(service_task)
    MiqRequestTask.find_by(:id => service_task.options[:parent_task_id])
  end

  def number_of_vms_from_dialog(root_svc, parent_task)
    return nil unless root_svc.options[:dialog]
    value = root_svc.options[:dialog]["dialog_option_0_number_of_vms"]
    if parent_task.service_resource
      index = parent_task.service_resource.provision_index
      value ||= root_svc.options[:dialog]["dialog_option_#{index + 1}_number_of_vms"]
    end
    value ||= root_svc.options[:dialog]["dialog_option_number_of_vms"]
    value ||= root_svc.options[:dialog]["dialog_number_of_vms"]
    value
  end
end
