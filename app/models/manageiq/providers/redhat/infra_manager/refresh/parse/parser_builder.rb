module ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse
  class ParserBuilder
    attr_reader :ext_management_system

    def initialize(ems)
      @ext_management_system = ems
    end

    def build
      parse_model = ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Strategies
      api_version = ext_management_system.highest_supported_api_version
      "#{parse_model}::Api#{api_version}".constantize
    end
  end
end
