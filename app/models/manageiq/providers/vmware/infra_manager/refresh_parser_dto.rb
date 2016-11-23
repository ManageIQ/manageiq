module ManageIQ::Providers::Vmware
  class InfraManager::RefreshParserDto < ManageIQ::Providers::InfraManager::RefreshParserDto
    include Vmdb::Logging

    def initialize(ems, options = Config::Options.new)
      super

      initialize_dto_collections
    end

    def initialize_dto_collections
    end

    #
    # EMS Inventory Parsing
    #
    def self.ems_inv_to_hashes(ems, inv, options = nil)
      new(ems, options).ems_inv_to_hashes(inv)
    end

    def ems_inv_to_hashes(inv)
      @data
    end
  end
end
