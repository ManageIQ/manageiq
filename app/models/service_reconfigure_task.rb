class ServiceReconfigureTask < MiqRequestTask
  validate :validate_request_type, :validate_state

  AUTOMATE_DRIVES = true

  def self.base_model
    ServiceReconfigureTask
  end

  def self.get_description(req_obj)
    "#{request_class::TASK_DESCRIPTION} for: #{req_obj.source.name}"
  end

  def after_request_task_create
    update(:description => get_description)
  end

  def deliver_to_automate(req_type = request_type, zone = nil)
    task_check_on_execute

    _log.info("Queuing #{request_class::TASK_DESCRIPTION}: [#{description}]...")
    dialog_values = options[:dialog] || {}

    ra = source.service_template.resource_actions.find_by(:action => 'Reconfigure')
    if ra
      dialog_values["request"] = req_type
      args = {
        :object_type      => self.class.name,
        :object_id        => id,
        :namespace        => ra.ae_namespace,
        :class_name       => ra.ae_class,
        :instance_name    => ra.ae_instance,
        :automate_message => ra.ae_message.blank? ? 'create' : ra.ae_message,
        :attrs            => dialog_values,
        :user_id          => get_user.id,
        :miq_group_id     => get_user.current_group_id,
        :tenant_id        => get_user.current_tenant.id
      }

      MiqQueue.put(
        :class_name     => 'MiqAeEngine',
        :method_name    => 'deliver',
        :args           => [args],
        :role           => 'automate',
        :zone           => zone,
        :tracking_label => tracking_label_id
      )
      update_and_notify_parent(:state => "pending", :status => "Ok",  :message => "Automation Starting")
    else
      update_and_notify_parent(:state   => "finished",
                               :status  => "Ok",
                               :message => "#{request_class::TASK_DESCRIPTION} completed")
    end
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
end
