class MiqProvisionConfigurationScriptTask < MiqRequestTask
  def self.get_description(req_obj)
    "#{request_class::TASK_DESCRIPTION} for: #{req_obj.source.name}"
  end
end
