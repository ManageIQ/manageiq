class ServiceReconfigureTask < MiqReconfigureTask
  validate :validate_request_type, :validate_state

  AUTOMATE_DRIVES = true

  def self.base_model
    ServiceReconfigureTask
  end

  def self.get_description(req_obj)
    "#{request_class::TASK_DESCRIPTION} for: #{req_obj.source.name}"
  end

  def statemachine_task_status
    state == "finished" ? status.to_s.downcase : "retry"
  end

  def after_request_task_create
    update(:description => get_description)
    return if automate_drives?

    # For services that drive reconfigure without Automate (e.g. ServiceEmbeddedTerraform), dispatch per-resource subtasks.
    Service.where(:id => options[:src_id]).each do |svc|
      _log.info("Creating reconfigure subtasks for service task <#{self.class.name}:#{id}>, service <#{svc.id}>")
      create_reconfigure_subtasks(svc, self)
    end
  end

  def deliver_to_automate(req_type = request_type, zone = nil)
    ra = resource_action
    if ra
      dialog_values["request"] = req_type
      args = {
        :object_type      => self.class.name,
        :object_id        => id,
        :namespace        => ra.ae_namespace,
        :class_name       => ra.ae_class,
        :instance_name    => ra.ae_instance,
        :automate_message => (ra.ae_message.presence || 'create'),
        :attrs            => dialog_values,
        :user_id          => get_user.id,
        :miq_group_id     => get_user.current_group_id,
        :tenant_id        => get_user.current_tenant.id
      }

      MiqAeEngine.set_automation_attributes_from_objects(source, args[:attrs])

      MiqQueue.put(
        :class_name     => 'MiqAeEngine',
        :method_name    => 'deliver',
        :args           => [args],
        :role           => 'automate',
        :zone           => zone,
        :tracking_label => tracking_label_id
      )
      update_and_notify_parent(:state => "pending", :status => "Ok", :message => "Automation Starting")
    else
      update_and_notify_parent(:state   => "finished",
                               :status  => "Ok",
                               :message => "#{request_class::TASK_DESCRIPTION} completed")
    end
  end

  def resource_action
    @resource_action ||= source.service_template.resource_actions.find_by(:action => 'Reconfigure')
  end

  def after_ae_delivery(ae_result)
    _log.info("ae_result=#{ae_result.inspect}")

    return if ae_result == 'retry'
    return if miq_request.state == 'finished'

    if ae_result == 'ok'
      source.options[:dialog] = source.options[:dialog].merge(options[:dialog]) if options[:dialog]
      source.save!

      update_and_notify_parent(:state   => "finished",
                               :status  => "Ok",
                               :message => "#{request_class::TASK_DESCRIPTION} completed")
    else
      update_and_notify_parent(:state   => "finished",
                               :status  => "Error",
                               :message => "#{request_class::TASK_DESCRIPTION} failed")
    end
  end

  private

  def automate_drives?
    source.class.const_defined?(:AUTOMATE_DRIVES) ? source.class::AUTOMATE_DRIVES : true
  end

  def create_reconfigure_subtasks(parent_service, parent_task)
    parent_service.service_resources.collect do |svc_rsc|
      next unless svc_rsc.resource.try(:reconfigurable?)
      next if svc_rsc.resource.respond_to?(:retired?) && svc_rsc.resource.retired?

      nh = attributes.except("id", "created_on", "updated_on", "type", "state", "status", "message")
      nh['options'] = options.except(:child_tasks)

      new_task = OrchestrationStackReconfigureTask.new(nh).tap do |task|
        task.options.merge!(
          :src_ids             => [svc_rsc.resource.id],
          :service_resource_id => svc_rsc.id,
          :parent_service_id   => parent_service.id,
          :parent_task_id      => parent_task.id
        )
        task.request_type = "orchestration_stack_reconfigure"
        task.source       = svc_rsc.resource
        parent_task.miq_request_tasks << task
        task.save!
      end

      miq_request.miq_request_tasks << new_task
      new_task.tap(&:deliver_queue)
    end.compact!
  end
end
