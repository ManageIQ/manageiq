class MiqProvisionTaskConfiguredSystemForeman < MiqProvisionTask
  include_concern 'OptionsHelper'
  include_concern 'StateMachine'

  def model_class
    ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem
  end

  def self.request_class
    MiqProvisionConfiguredSystemRequest
  end

  def deliver_to_automate
    super("configured_system_provision", my_zone)
  end

  def after_ae_delivery(ae_result)
    _log.info("ae_result=#{ae_result.inspect}")

    return if ae_result == 'retry'
    return if miq_request.state == 'finished'

    if ae_result == 'ok'
      update_and_notify_parent(:state => "finished", :status => "Ok", :message => "#{request_class::TASK_DESCRIPTION} completed")
    else
      update_and_notify_parent(:state => "finished", :status => "Error")
    end
  end
end
