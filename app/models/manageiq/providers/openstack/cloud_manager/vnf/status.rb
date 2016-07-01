class ManageIQ::Providers::Openstack::CloudManager::Vnf::Status < ::OrchestrationStack::Status
  def succeeded?
    status.downcase == "active"
  end

  def failed?
    status.downcase =~ /failed$/ || status.downcase == "error"
  end

  def rolled_back?
    status.downcase == "rollback_complete"
  end

  def deleted?
    status.downcase == "delete_complete"
  end

  def updated?
    status.downcase == "update_complete"
  end
end
