module Spec
  module Support
    module EmsRefreshHelper
      class TestPersister < ManageIQ::Providers::Inventory::Persister
        def initialize_inventory_collections
          add_collection(infra, :vms)
          add_collection(infra, :hosts)
        end
      end
    end
  end
end
