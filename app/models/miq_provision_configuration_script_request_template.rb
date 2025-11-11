class MiqProvisionConfigurationScriptRequestTemplate < MiqProvisionConfigurationScriptRequest
  def create_tasks_for_service(service_task, parent_svc)
    template_service_resource = ServiceResource.find_by(:id => service_task.options[:service_resource_id])
    scaling_min = 1

    _log.info("create_tasks_for_service ID #{service_task.id} SCALING : #{scaling_min}")
    scaling_min.times.collect do |idx|
      create_request_task(idx) do |req_task|
        req_task.miq_request_id = service_task.miq_request.id
        req_task.userid         = service_task.userid

        task_options     = req_task.options.merge(service_options(parent_svc, service_task, template_service_resource))
        task_options     = task_options.merge(owner_options(service_task))
        req_task.options = task_options
      end
    end
  end

  def request_task_class
    MiqProvisionConfigurationScriptTask
  end

  def get_source_name
    SecureRandom.uuid # TODO
  end

  def post_create(_auto_approve)
    update(:description => "Miq Provision ConfigurationScript Request Template for #{source.name}")
    self
  end

  def service_template_resource_copy
    dup.tap(&:save!)
  end

  def execute
    # Should not be called.
    raise _("Provision ConfigurationScript Request Templates do not support the execute method.")
  end

  private

  def service_options(parent_svc, service_task, template_service_resource)
    {
      :miq_force_unique_name           => [true, 1],
      :service_guid                    => parent_svc.guid,
      :service_resource_id             => template_service_resource.id,
      :service_template_request        => false,
      :configuration_script_payload_id => service_task.options&.dig(:parent_configuration_script_payload_id)
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

  def get_root_svc(parent_svc)
    return nil unless parent_svc

    parent_svc.parent || parent_svc
  end

  def get_parent_task(service_task)
    MiqRequestTask.find_by(:id => service_task.options[:parent_task_id])
  end
end
