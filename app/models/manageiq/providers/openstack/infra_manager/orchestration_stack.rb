class ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack < ::OrchestrationStack
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::InfraManager"
  belongs_to :orchestration_template
  belongs_to :cloud_tenant

  def self.create_stack(orchestration_manager, stack_name, template, options = {})
    klass = orchestration_manager.class::OrchestrationStack
    ems_ref = klass.raw_create_stack(orchestration_manager, stack_name, template, options)

    klass.create(:name                   => stack_name,
                 :ems_ref                => ems_ref,
                 :status                 => 'CREATE_IN_PROGRESS',
                 :resource_group         => options[:resource_group],
                 :ext_management_system  => orchestration_manager,
                 :cloud_tenant           => tenant,
                 :orchestration_template => template)
  end

  def raw_update_stack(template, parameters)
    ext_management_system.with_provider_connection(:service => "Orchestration") do |connection|
      stack    = connection.stacks.get(name, ems_ref)
      template ||= connection.get_stack_template(stack).body

      connection.patch_stack(stack, 'template' => template, 'parameters' => parameters)
    end
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationUpdateError, err.to_s, err.backtrace
  end

  def update_ready?
    # Update is possible only when in complete or failed state, otherwise API returns exception
    raw_status.first.end_with?("_COMPLETE", "_FAILED")
  end

  def raw_delete_stack
    options = {:service => "Orchestration"}
    options.merge!(:tenant_name => cloud_tenant.name) if cloud_tenant
    ext_management_system.with_provider_connection(options) do |service|
      service.stacks.get(name, ems_ref).try(:delete)
    end
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationDeleteError, err.to_s, err.backtrace
  end

  def raw_status
    ems = ext_management_system
    ems.with_provider_connection(:service => "Orchestration") do |service|
      raw_stack = service.stacks.get(name, ems_ref)
      raise MiqException::MiqOrchestrationStackNotExistError, "#{name} does not exist on #{ems.name}" unless raw_stack

      # TODO(lsmola) implement Status class, like in Cloud Manager, or make it common superclass
      [raw_stack.stack_status, raw_stack.stack_status_reason]
    end
  rescue MiqException::MiqOrchestrationStackNotExistError
    raise
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end

  def queue_post_scaledown_task(services, task_id = nil)
    MiqQueue.put(:class_name  => self.class.name,
                 :expires_on  => Time.now.utc + 2.hours,
                 :args        => [services, task_id],
                 :instance_id => id,
                 :method_name => "post_scaledown_task")
  end

  def post_scaledown_task(services, task_id = nil)
    task = MiqTask.find(task_id) unless task_id.nil?
    if task && task.state == MiqTask::STATE_FINISHED && !task.status_ok?
      raise MiqException::MiqQueueError, "Scaledown update failed, not running post scaledown task"
    end
    raise MiqException::MiqQueueRetryLater.new(:deliver_on => Time.now.utc + 1.minute) unless raw_status.first == 'UPDATE_COMPLETE'
    services.each(&:delete_service)
  end
end
