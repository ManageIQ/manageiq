class AutomationTask < MiqRequestTask
  alias_attribute :automation_request, :miq_request

  AUTOMATE_DRIVES = false

  def self.get_description(request_obj)
    return "Automation Task"
  end

  def self.base_model
    AutomationTask
  end

  def do_request
    args = {}
    args[:object_type]      = self.class.name
    args[:object_id]        = self.id
    args[:attrs]            = self.options[:attrs]
    args[:namespace]        = self.options[:namespace]
    args[:class_name]       = self.options[:class_name]
    args[:instance_name]    = self.options[:instance_name]
    args[:user_id]          = self.options[:user_id]
    args[:automate_message] = self.options[:message]

    ws = MiqAeEngine.deliver(args)
  end

  def after_ae_delivery(ae_result)
    log_header = "MIQ(#{self.class.name}.after_ae_delivery)"

    $log.info("#{log_header} ae_result=#{ae_result.inspect}")

    return if ae_result == 'retry'
    return if self.miq_request.state == 'finished'

    if ae_result == 'ok'
      update_and_notify_parent(:state => "finished", :status => "Ok",    :message => "#{self.request_class::TASK_DESCRIPTION} completed")
    else
      update_and_notify_parent(:state => "finished", :status => "Error", :message => "#{self.request_class::TASK_DESCRIPTION} failed")
    end
  end
end
