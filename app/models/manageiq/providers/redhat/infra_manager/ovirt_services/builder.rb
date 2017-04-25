module ManageIQ::Providers::Redhat::InfraManager::OvirtServices
  class Builder
    attr_reader :ext_management_system

    def initialize(ems)
      @ext_management_system = ems
    end

    def build(args = {})
      strategy_model = ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Strategies
      "#{strategy_model}::V#{api_version(args)}".constantize
    end

    def self.build_from_ems_or_connection(args)
      ems = args[:ems]
      connection = args[:connection]
      connection_version = connection && connection.kind_of?(OvirtSDK4::Connection) ? 4 : 3
      strategy_model = ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Strategies
      return "#{strategy_model}::V#{connection_version}".constantize if connection_version
      new(ems).build if ems
    end

    def api_version(args)
      return ext_management_system.highest_supported_api_version if args[:use_highest_supported_version]
      ext_management_system.highest_allowed_api_version
    end
  end
end
