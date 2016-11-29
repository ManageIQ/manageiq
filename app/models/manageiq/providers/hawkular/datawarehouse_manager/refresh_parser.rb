module ManageIQ::Providers
  class Hawkular::DatawarehouseManager::RefreshParser
    def self.ems_inv_to_hashes(ems, options = nil)
      new(ems, options).ems_inv_to_hashes
    end

    def initialize(_ems, _options = nil)
      @data = {}
      @data_index = {}
    end

    def ems_inv_to_hashes
      @data
    end
  end
end
