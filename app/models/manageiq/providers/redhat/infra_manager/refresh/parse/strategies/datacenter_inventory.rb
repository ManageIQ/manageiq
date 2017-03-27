module ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Strategies
  class DatacenterInventory
    attr_reader :datacenter_inv, :logger

    def initialize(args)
      @datacenter_inv = args[:inv]
      @logger = args[:logger]
    end

    def datacenter_inv_to_hashes(inv, cluster_uids, vm_uids, storage_uids, host_uids)
      result = [{
        :name         => 'Datacenters',
        :type         => 'EmsFolder',
        :uid_ems      => 'root_dc',
        :hidden       => true,

        :ems_children => {:folders => []}
      }]
      return result if inv.nil?

      root_children = result.first[:ems_children][:folders]

      inv.each do |data|
        uid = data.id

        host_folder = {:name => 'host', :type => 'EmsFolder', :uid_ems => "#{uid}_host", :hidden => true}
        vm_folder   = {:name => 'vm',   :type => 'EmsFolder', :uid_ems => "#{uid}_vm",   :hidden => true}

        # Link clusters to datacenter host folder
        clusters = cluster_uids.values.select { |c| c[:datacenter_id] == uid }
        host_folder[:ems_children] = {:clusters => clusters}

        # Link vms to datacenter vm folder
        vms = vm_uids.values.select { |v| v.fetch_path(:ems_cluster, :datacenter_id) == uid }
        vm_folder[:ems_children] = {:vms => vms}

        ems_ref = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(data.href)

        new_result = {
          :name         => data.name,
          :type         => 'Datacenter',
          :ems_ref      => ems_ref,
          :ems_ref_obj  => ems_ref,
          :uid_ems      => uid,

          :ems_children => {:folders => [host_folder, vm_folder]}
        }

        result << new_result
        result << host_folder
        result << vm_folder
        root_children << new_result

        # Link hosts to storages
        hosts = host_uids.values.select { |v| v.fetch_path(:ems_cluster, :datacenter_id) == uid }
        storage_ids = data.storage_domains.to_miq_a.collect(&:id)
        hosts.each { |h| h[:storages] = storage_uids.values_at(*storage_ids).compact } unless storage_ids.blank?
      end

      result
    end
  end
end
