$:.push("#{File.dirname(__FILE__)}/../../../../../lib/VdiCitrix")
require 'VdiCitrixInventory'

module VdiRefresh::Refreshers
  class CitrixRefresher < PowershellRefresherBase
    def self.inventory_class
      VdiCitrixInventory
    end
  end
end
