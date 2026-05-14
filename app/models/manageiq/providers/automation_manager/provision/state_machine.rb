module ManageIQ::Providers::AutomationManager::Provision::StateMachine
  private

  def connect_to_service!(stack, options = {})
    service&.add_resource!(stack, options)
  end

  def service
    @service ||= Service.find_by(:guid => options[:service_guid])
  end
end
