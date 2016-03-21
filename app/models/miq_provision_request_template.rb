class MiqProvisionRequestTemplate < MiqProvisionRequest
  def create_tasks_for_service(service_task, parent_svc)
    template_service_resource = ServiceResource.find_by_id(service_task.options[:service_resource_id])
    scaling_min = template_service_resource.try(:scaling_min) || 1

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
    user = User.find_by_userid(service_task.userid)
    return {} if user.nil?

    {
      :requester_group  => service_task.options[:requester_group],
      :owner_email      => user.email,
      :owner_group      => service_task.options[:requester_group],
      :owner_first_name => user.first_name,
      :owner_last_name  => user.last_name
    }
  end
end
