module Spec
  module Support
    module EmsRefreshHelper
      class TestPersister < ManageIQ::Providers::Inventory::Persister
        def initialize_inventory_collections
          add_collection(infra, :vms, {}, :without_sti => true)
          add_collection(infra, :hosts, {}, :without_sti => true)
        end
      end
    end
  end
end
