module ManageIQ::Providers::Redhat::InfraManager::OvirtServices
  class Error < StandardError; end
  class VmNotReadyToBoot < Error; end
end
