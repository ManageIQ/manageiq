module ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse
  class ParserBuilder
    attr_reader :ext_management_system, :force_version

    def initialize(ems, options = {})
      @ext_management_system = ems
      @force_version = options[:force_version]
    end

    def build
      parse_model = ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Strategies
      api_version = force_version || ext_management_system.highest_supported_api_version
      "#{parse_model}::Api#{api_version}".constantize
    end
  end
end
