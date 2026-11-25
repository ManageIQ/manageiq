module ManageIQ::Providers
  class Inventory::Persister
    class Builder
      class HpcManager < ::ManageIQ::Providers::Inventory::Persister::Builder
        def hpc_queues
          add_properties(
            :delete_method => :disconnect_inv
          )
          add_common_default_values
        end

        def hpc_nodes
          add_properties(
            :delete_method => :disconnect_inv
          )
          add_common_default_values
        end

        def hpc_jobs
          add_properties(
            :delete_method => :disconnect_inv
          )
          add_common_default_values
        end
      end
    end
  end
end
