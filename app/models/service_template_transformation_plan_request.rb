class ServiceTemplateTransformationPlanRequest < ServiceTemplateProvisionRequest
  TASK_DESCRIPTION = 'VM Transformations'.freeze

  delegate :transformation_mapping, :vm_requests, :to => :source

  def requested_task_idx
    vm_requests.where(:status => 'Approved')
  end

  def customize_request_task_attributes(req_task_attrs, vm_request)
    req_task_attrs[:source] = vm_request.resource
  end

  def source_vms
    vm_requests.where(:status => %w(Queued Failed)).pluck(:resource_id)
  end

  def validate_vm(_vm_id)
    # TODO: enhance the logic to determine whether this VM can be included in this request
    true
  end

  def approve_vm(vm_id)
    vm_requests.find_by(:resource_id => vm_id).update_attributes!(:status => 'Approved')
  end
end
