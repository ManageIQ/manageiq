module ManageIQ::Providers::Redhat::InfraManager::OvirtServices
  class Builder
    attr_reader :ext_management_system

    def initialize(ems)
      @ext_management_system = ems
    end

    def build
      strategy_model = ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Strategies
      api_version = ext_management_system.highest_allowed_api_version
      "#{strategy_model}::V#{api_version}".constantize
    end

    def self.build_from_ems_or_connection(args)
      ems = args[:ems]
      connection = args[:connection]
      return new(ems).build if ems
      strategy_model = ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Strategies
      api_version = connection.kind_of?(OvirtSDK4::Connection) ? 4 : 3
      "#{strategy_model}::V#{api_version}".constantize
    end
  end
end
