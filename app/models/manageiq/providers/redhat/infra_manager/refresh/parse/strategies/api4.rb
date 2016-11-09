module ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Strategies
  class Api4 < ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Parser
    def self.cluster_inv_to_hashes(inv)
      result = []
      result_uids = {}
      result_res_pools = []
      return result, result_uids, result_res_pools if inv.nil?

      inv.each do |data|
        mor = data.id

        # Create a default Resource Pool for the cluster
        default_res_pool = {
          :name         => "Default for Cluster #{data.name}",
          :uid_ems      => "#{mor}_respool",
          :is_default   => true,
          :ems_children => {:vms => []}
        }
        result_res_pools << default_res_pool

        ems_ref = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(data.href)

        new_result = {
          :ems_ref       => ems_ref,
          :ems_ref_obj   => ems_ref,
          :uid_ems       => data.id,
          :name          => data.name,

          # Capture datacenter id so we can link up to it's sub-folders later
          :datacenter_id => data&.data_center&.id,

          :ems_children  => {:resource_pools => [default_res_pool]}
        }

        result << new_result
        result_uids[mor] = new_result
      end
      return result, result_uids, result_res_pools
    end
  end
end
