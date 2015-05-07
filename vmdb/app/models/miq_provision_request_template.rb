class MiqProvisionRequestTemplate < MiqProvisionRequest
  def create_tasks_for_service(service_task, parent_svc)
    template_service_resource = ServiceResource.find_by_id(service_task.options[:service_resource_id])
    scaling_min = template_service_resource.nil? ? 1 : template_service_resource.scaling_min

    0.upto(scaling_min - 1).collect do |idx|
      task = create_request_task(idx)
      update_service_options(task, parent_svc, template_service_resource)
      update_owner(task, service_task)
      req_task.miq_request_id = service_task.miq_request.id
      task
    end
  end

  def request_task_class
    MiqProvision
  end

  def execute
    # Should not be called.
    raise "Provision Request Templates do not support the execute method."
  end

  private

  def update_service_options(task, parent_svc, template_service_resource)
    task.options = task.options.merge(
      :miq_force_unique_name    => [true, 1],
      :service_guid             => parent_svc.guid,
      :service_resource_id      => template_service_resource.id,
      :service_template_request => false
    )
  end

  def update_owner(task, service_task)
    task.userid = service_task.userid
    user = User.find_by_userid(task.userid)
    return if user.nil?

    task.options = task.options.merge(
      :owner_email      => user.email,
      :owner_first_name => user.first_name,
      :owner_last_name  => user.last_name
    )
  end
end
