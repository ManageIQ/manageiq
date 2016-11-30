module ManageIQ::Providers::Redhat::InfraManager::Refresh
  class RefresherBuilder
    attr_reader :ext_management_system

    def initialize(ems)
      @ext_management_system = ems
    end

    def build
      strategy_model = ManageIQ::Providers::Redhat::InfraManager::Refresh::Strategies
      api_version = ext_management_system.highest_supported_api_version
      "#{strategy_model}::Api#{api_version}".constantize
    end
  end
end
