module Metric::Targets
  cache_with_timeout(:perf_capture_always, 1.minute) do
    MiqRegion.my_region.perf_capture_always
  end

  def self.perf_capture_always=(options)
    perf_capture_always_clear_cache
    MiqRegion.my_region.perf_capture_always = options
  end

  def self.capture_infra_targets(emses, options)
    load_infra_targets_data(emses, options)
    all_hosts = capture_host_targets(emses)
    targets = enabled_hosts = only_enabled(all_hosts)
    targets += capture_storage_targets(all_hosts) unless options[:exclude_storages]
    targets += capture_vm_targets(emses, enabled_hosts)

    targets
  end

  # Filter to enabled hosts. If it has a cluster consult that, otherwise consult the host itself.
  #
  # NOTE: if capture_storage takes only enabled, then move
  # this logic into capture_host_targets
  def self.only_enabled(hosts)
    hosts.select do |host|
      host.supports_capture? && (host.ems_cluster ? host.ems_cluster.perf_capture_enabled? : host.perf_capture_enabled?)
    end
  end

  # @return vms under all availability zones
  #         and vms under no availability zone
  # NOTE: some stacks (e.g. nova) default to no availability zone
  def self.capture_cloud_targets(emses, options = {})
    MiqPreloader.preload(emses, :vms => [{:availability_zone => :tags}, :ext_management_system])

    emses.flat_map(&:vms).select do |vm|
      vm.state == 'on' && (vm.availability_zone.nil? || vm.availability_zone.perf_capture_enabled?)
    end
  end

  def self.with_archived(scope)
    # We will look also for freshly archived entities, if the entity was short-lived or even sub-hour
    archived_from = Metric::Capture.targets_archived_from
    scope.where(:deleted_on => nil).or(scope.where(:deleted_on => (archived_from..Time.now.utc)))
  end

  def self.capture_container_targets(emses, _options)
    includes = {
      :container_nodes  => :tags,
      :container_groups => [:tags, :containers => :tags],
    }

    MiqPreloader.preload(emses, includes)

    targets = []
    emses.each do |ems|
      next unless ems.supports_metrics?

      targets += with_archived(ems.all_container_nodes)
      targets += with_archived(ems.all_container_groups)
      targets += with_archived(ems.all_containers)
    end

    targets
  end

  # preload emses with relations that will be used in cap&u
  #
  # tags are needed for determining if it is enabled.
  # ems is needed for determining queue name
  # cluster is used for hierarchies
  def self.load_infra_targets_data(emses, options)
    MiqPreloader.preload(emses, preload_hash_infra_targets_data(options))
    postload_infra_targets_data(emses, options)
  end

  def self.preload_hash_infra_targets_data(options)
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
  def self.postload_infra_targets_data(emses, options)
    # populate ems (with tags / clusters)
    emses.each do |ems|
      ems.hosts.each do |host|
        host.ems_cluster.association(:ext_management_system).target = ems if host.ems_cluster_id
        unless options[:exclude_storages]
          host.storages.each do |storage|
            storage.ext_management_system = ems
          end
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
  end

  def self.capture_host_targets(emses)
    # NOTE: if capture_storage_targets takes only enabled hosts
    # merge only_enabled into this method
    emses.flat_map(&:hosts)
  end

  # @param [Host] all hosts that have an ems
  # NOTE: disabled hosts are passed in.
  # @return [Array<Storage>] supported storages
  # hosts preloaded storages and tags
  def self.capture_storage_targets(hosts)
    hosts.flat_map(&:storages).uniq.select { |s| Storage.supports?(s.store_type) & s.perf_capture_enabled? }
  end

  # @param [Array<ExtManagementSystem>] emses Typically 1 ems for this zone
  # @param [Host] hosts that are enabled or cluster enabled
  # we want to work with only enabled_hosts, so hosts needs to be further filtered
  def self.capture_vm_targets(emses, hosts)
    enabled_host_ids = hosts.select(&:perf_capture_enabled?).index_by(&:id)
    emses.flat_map { |e| e.vms.select { |v| enabled_host_ids.key?(v.host_id) && v.state == 'on' && v.supports_capture? } }
  end

  # If a Cluster, standalone Host, or Storage is not enabled, skip it.
  # If a Cluster is enabled, capture all of its Hosts.
  # If a Host is enabled, capture all of its Vms.
  def self.capture_targets(zone = nil, options = {})
    zone = MiqServer.my_server.zone if zone.nil?
    zone = Zone.find(zone) if zone.kind_of?(Integer)
    capture_infra_targets(zone.ext_management_systems, options) + \
      capture_cloud_targets(zone.ems_clouds, options) + \
      capture_container_targets(zone.ems_containers, options)
  end
end
