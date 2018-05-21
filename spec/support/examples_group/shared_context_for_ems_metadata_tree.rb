shared_context "simple ems_metadata tree" do
  #####################
  # Context Variables #
  #####################

  # These can be updated to increase the amount of data in the tree

  let(:cluster_count)     { 2 }
  let(:hosts_per_cluster) { 2 }
  let(:vms_per_host)      { 2 }

  ###############
  # Base models #
  ###############

  let(:ems)      { FactoryGirl.create(:ems_infra) }
  let(:clusters) { FactoryGirl.create_list(:ems_cluster, cluster_count, :ext_management_system => ems) }

  let(:hosts) do
    hosts = []
    clusters.each do |cluster|
      hosts += FactoryGirl.create_list(:host, hosts_per_cluster,
                                       :ext_management_system => ems,
                                       :ems_cluster           => cluster)
    end
    hosts
  end

  let(:vms) do
    vms = []
    hosts.each do |host|
      vms += FactoryGirl.create_list(:vm, vms_per_host,
                                     :ext_management_system => ems,
                                     :host                  => host)
    end
    vms
  end

  #################
  # Relationships #
  #################

  let(:ems_rel)      { ems.init_relationship }
  let(:cluster_rels) { clusters.map { |cluster| cluster.init_relationship(ems_rel) } }

  # The next to use a integer division trick to map the proper parent_rel to
  # the record being created (the `[index / child_per_parent]` part)

  let(:host_rels) do
    hosts.map.with_index do |host, index|
      host.init_relationship(cluster_rels[index / hosts_per_cluster])
    end
  end

  let(:vm_rels) do
    vms.map.with_index do |vm, index|
      vm.init_relationship(host_rels[index / vms_per_host])
    end
  end

  ###########
  # Helpers #
  ###########

  # Convenience statement for initializing the tree (there is no included
  # `before` to do this automatically
  let(:init_full_tree) { vm_rels }
end
