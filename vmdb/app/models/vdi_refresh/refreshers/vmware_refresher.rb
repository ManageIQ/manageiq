$:.push("#{File.dirname(__FILE__)}/../../../../../lib/VdiVmware")
require 'VdiVmwareInventory'

module VdiRefresh::Refreshers
  class VmwareRefresher < PowershellRefresherBase
    def self.inventory_class
      VdiVmwareInventory
    end
  end
end
