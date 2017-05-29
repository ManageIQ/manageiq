module ManageIQ::Providers::Redhat::InfraManager::Refresh
  class RefresherBuilder
    attr_reader :ext_management_system

    def initialize(ems)
      @ext_management_system = ems
    end

    def build
      strategy_model = ManageIQ::Providers::Redhat::InfraManager::Refresh::Strategies
      api_version = ext_management_system.highest_allowed_api_version
      if api_version.nil?
        # versions not fetched due to connectivity issues
        api_version = '4'
      end
      "#{strategy_model}::Api#{api_version}".constantize
    end
  end
end
