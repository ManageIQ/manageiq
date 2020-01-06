class ManageIQ::Providers::InfraManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  def capture_ems_targets(options = {})
    load_infra_targets_data(ems, options)
    all_hosts = capture_host_targets(ems)
    targets = enabled_hosts = only_enabled(all_hosts)
    targets += capture_storage_targets(all_hosts) unless options[:exclude_storages]
    targets += capture_vm_targets(ems, enabled_hosts)

    targets
  end

  private

  # Filter to enabled hosts. If it has a cluster consult that, otherwise consult the host itself.
  #
  # NOTE: if capture_storage takes only enabled, then move
  # this logic into capture_host_targets
  def only_enabled(hosts)
    hosts.select do |host|
      host.supports_capture? && (host.ems_cluster ? host.ems_cluster.perf_capture_enabled? : host.perf_capture_enabled?)
    end
  end

  # preload emses with relations that will be used in cap&u
  #
  # tags are needed for determining if it is enabled.
  # ems is needed for determining queue name
  # cluster is used for hierarchies
  def load_infra_targets_data(ems, options)
    MiqPreloader.preload(ems, preload_hash_infra_targets_data(options))
    postload_infra_targets_data(ems, options)
  end

  def preload_hash_infra_targets_data(options)
    # Preload all of the objects we are going to be inspecting.
    includes = {:hosts => {:ems_cluster => :tags, :tags => {}}}
    includes[:hosts][:storages] = :tags unless options[:exclude_storages]
    includes[:vms] = {}
    includes
  end

  # populate parts of the hierarchy that are not properly preloaded
  #
  # inverse_of does not work with :through.
  # e.g.: :ems => :hosts => vms will not preload vms.ems
  #
  # adding in a preload for vms => :ems will fix, but different objects get assigned
  # and since we also rely upon tags and clusters, this causes unnecessary data to be downloaded
  #
  # so we have introduced this to work around preload not working (and inverse_of)
  def postload_infra_targets_data(ems, options)
    # populate ems (with tags / clusters)
    ems.hosts.each do |host|
      host.ems_cluster.association(:ext_management_system).target = ems if host.ems_cluster_id
      next if options[:exclude_storages]

      host.storages.each do |storage|
        storage.ext_management_system = ems
      end
    end
    host_ids = ems.hosts.index_by(&:id)
    clusters = ems.hosts.flat_map(&:ems_cluster).uniq.compact.index_by(&:id)
    ems.vms.each do |vm|
      vm.association(:ext_management_system).target = ems if vm.ems_id
      vm.association(:ems_cluster).target = clusters[vm.ems_cluster_id] if vm.ems_cluster_id
      vm.association(:host).target = host_ids[vm.host_id] if vm.host_id
    end
  end

  def capture_host_targets(ems)
    # NOTE: if capture_storage_targets takes only enabled hosts
    # merge only_enabled into this method
    ems.hosts
  end

  # @param [Array<Host>] all hosts that have an ems
  # NOTE: disabled hosts are passed in.
  # @return [Array<Storage>] supported storages
  # hosts preloaded storages and tags
  def capture_storage_targets(hosts)
    hosts.flat_map(&:storages).uniq.select { |s| Storage.supports?(s.store_type) & s.perf_capture_enabled? }
  end

  # @param [ExtManagementSystem] ems
  # @param [Array<Host>] hosts that are enabled or cluster enabled
  # we want to work with only enabled_hosts, so hosts needs to be further filtered
  def capture_vm_targets(ems, hosts)
    enabled_host_ids = hosts.select(&:perf_capture_enabled?).index_by(&:id)
    ems.vms.select { |v| enabled_host_ids.key?(v.host_id) && v.state == 'on' && v.supports_capture? }
  end
end
