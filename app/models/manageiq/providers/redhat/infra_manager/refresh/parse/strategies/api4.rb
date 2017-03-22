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
          :datacenter_id => data.dig(:data_center, :id),

          :ems_children  => {:resource_pools => [default_res_pool]}
        }

        result << new_result
        result_uids[mor] = new_result
      end
      return result, result_uids, result_res_pools
    end

    def self.storage_inv_to_hashes(inv)
      result = []
      result_uids = {:storage_id => {}}
      return result, result_uids if inv.nil?

      inv.each do |storage_inv|
        mor = storage_inv.id

        storage_type = storage_inv.dig(:storage, :type).upcase
        location = if storage_type == 'NFS' || storage_type == 'GLUSTERFS'
                     "#{storage_inv.dig(:storage, :address)}:#{storage_inv.dig(:storage, :path)}"
                   else
                     # TODO: this is taking only one location for some reason. Need to investigate
                     # how this is used
                     logical_units = storage_inv.dig(:storage, :volume_group, :logical_units)
                     logical_unit =  logical_units && logical_units.first
                     logical_unit && logical_unit.id
                   end

        free        = storage_inv.try(:available).to_i
        used        = storage_inv.try(:used).to_i
        total       = free + used
        committed   = storage_inv.try(:committed).to_i
        uncommitted = total - committed

        ems_ref = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(storage_inv.try(:href))

        new_result = {
          :ems_ref             => ems_ref,
          :ems_ref_obj         => ems_ref,
          :name                => storage_inv.try(:name),
          :store_type          => storage_type,
          :storage_domain_type => storage_inv.dig(:type, :downcase),
          :total_space         => total,
          :free_space          => free,
          :uncommitted         => uncommitted,
          :multiplehostaccess  => true,
          :location            => location,
          :master              => storage_inv.try(:master)
        }

        result << new_result
        result_uids[mor] = new_result
        result_uids[:storage_id][storage_inv.try(:id)] = new_result
      end
      return result, result_uids
    end

    def self.host_inv_to_hashes(inv, ems_inv, cluster_uids, storage_uids)
      HostInventory.new(:inv => inv, :logger => _log).host_inv_to_hashes(inv, ems_inv, cluster_uids, storage_uids)
    end

    def self.vm_inv_to_hashes(inv, storage_inv, storage_uids, cluster_uids, host_uids, lan_uids)
      VmInventory.new(:inv => inv, :logger => _log).vm_inv_to_hashes(inv, storage_inv, storage_uids, cluster_uids, host_uids, lan_uids)
    end

    def self.datacenter_inv_to_hashes(inv, cluster_uids, vm_uids, storage_uids, host_uids)
      DatacenterInventory.new(:inv => inv, :logger => _log).datacenter_inv_to_hashes(inv, cluster_uids, vm_uids, storage_uids, host_uids)
    end
  end
end
