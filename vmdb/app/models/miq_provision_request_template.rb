class MiqProvisionRequestTemplate < MiqProvisionRequest

  def create_tasks_for_service(service_task, parent_svc)

    template_service_resource = ServiceResource.find_by_id(service_task.options[:service_resource_id])
    scaling_min = template_service_resource.nil? ? 1 : template_service_resource.scaling_min

    tasks = []
    0.upto(scaling_min - 1).each do |idx|

      task = self.create_request_task(idx)
      task.options[:miq_force_unique_name] = [true, 1]
      task.options[:service_guid] = parent_svc.guid
      task.options[:service_resource_id] = template_service_resource.id
      task.options[:service_template_request] = false
      task.userid = service_task.userid
      user = User.find_by_userid(task.userid)
      unless user.nil?
        task.options[:owner_email]      = user.email
        task.options[:owner_first_name] = user.first_name
        task.options[:owner_last_name]  = user.last_name
      end
      task.save!
      task.after_request_task_create
      service_task.miq_request.miq_request_tasks << task

      tasks << task
    end

    return tasks
  end

  def request_task_class
    MiqProvision
  end

  def execute
    # Should not be called.
    raise "Provision Request Templates do not support the execute method."
  end
end
