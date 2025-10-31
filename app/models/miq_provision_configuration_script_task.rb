class MiqProvisionConfigurationScriptTask < MiqRequestTask
  def self.get_description(request)
    "#{request_class::TASK_DESCRIPTION} for #{request.source&.name}"
  end
end
