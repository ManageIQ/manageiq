module ManageIQ::Providers::Redhat::InfraManager::Inventory::Strategies
  class V3
    attr_reader :ext_management_system

    def initialize(args)
      @ext_management_system = args[:ems]
    end
  end
end
