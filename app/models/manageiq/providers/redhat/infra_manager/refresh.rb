module ManageIQ::Providers::Redhat::InfraManager::Refresh
  require_nested :Parse
  require_nested :Refresher

  def self.ems_type
    "rhevm"
  end
end
