module ManageIQ::Providers::Redhat::InfraManager::Inventory
  class Error < StandardError; end
  class VmNotReadyToBoot < Error; end
end
