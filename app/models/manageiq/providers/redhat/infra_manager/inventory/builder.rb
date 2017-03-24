module ManageIQ::Providers::Redhat::InfraManager::Inventory
  class Builder
    attr_reader :ext_management_system

    def initialize(ems)
      @ext_management_system = ems
    end

    def build
      strategy_model = ManageIQ::Providers::Redhat::InfraManager::Inventory::Strategies
      api_version = ext_management_system.highest_supported_api_version
      "#{strategy_model}::V#{api_version}".constantize
    end
  end
end
