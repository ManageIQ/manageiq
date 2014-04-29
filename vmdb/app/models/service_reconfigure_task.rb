class ServiceReconfigureTask < MiqRequestTask
  include ReportableMixin

  validates_inclusion_of :request_type,
                         :in      => request_class::REQUEST_TYPES,
                         :message => "should be #{request_class::REQUEST_TYPES.join(", ")}"
  validates_inclusion_of :state,
                         :in      => %w(pending finished) + request_class::ACTIVE_STATES,
                         :message => "should be pending, #{request_class::ACTIVE_STATES.join(", ")} or finished"

  AUTOMATE_DRIVES  = true

  def self.base_model
    ServiceReconfigureTask
  end

  def self.get_description(req_obj)
    "#{request_class::TASK_DESCRIPTION} for: #{req_obj.source.name}"
  end

  def after_request_task_create
    update_attributes(:description => get_description)
  end

  def deliver_to_automate(req_type = request_type, zone = nil)
    log_header = "MIQ(#{self.class.name}.deliver_to_automate)"
    task_check_on_execute

    $log.info("#{log_header} Queuing #{request_class::TASK_DESCRIPTION}: [#{description}]...")
    dialog_values = options[:dialog] || {}

    ra = source.service_template.resource_actions.find_by_action('Reconfigure')
    if ra
      args = {
        :object_type      => self.class.name,
        :object_id        => id,
        :namespace        => ra.ae_namespace,
        :class_name       => ra.ae_class,
        :instance_name    => ra.ae_instance,
        :automate_message => ra.ae_message.blank? ? 'create' : ra.ae_message,
        :attrs            => dialog_values.merge!("request" => req_type),
        :user_id          => get_user.id
      }

      MiqQueue.put(
        :class_name  => 'MiqAeEngine',
        :method_name => 'deliver',
        :args        => [args],
        :role        => 'automate',
        :zone        => zone,
        :task_id     => "#{self.class.name.underscore}_#{id}"
      )
      update_and_notify_parent(:state => "pending", :status => "Ok",  :message => "Automation Starting")
    else
      update_and_notify_parent(:state   => "finished",
                               :status  => "Ok",
                               :message => "#{request_class::TASK_DESCRIPTION} completed")
    end
  end

  def after_ae_delivery(ae_result)
    log_header = "MIQ(#{self.class.name}.after_ae_delivery)"

    $log.info("#{log_header} ae_result=#{ae_result.inspect}")

    return if ae_result == 'retry'
    return if miq_request.state == 'finished'

    if ae_result == 'ok'
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
