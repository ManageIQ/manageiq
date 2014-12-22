module Metric::Targets
  cache_with_timeout(:perf_capture_always, 1.minute) do
    MiqRegion.my_region.perf_capture_always
  end

  def self.perf_capture_always=(options)
    perf_capture_always_clear_cache
    MiqRegion.my_region.perf_capture_always = options
  end

  def self.capture_infra_targets(zone, options = {})
    # Preload all of the objects we are going to be inspecting.
    # TODO: Include hosts under clusters
    includes = {:ext_management_systems => {:hosts => {:tags => {}}, :ems_clusters => :tags}}
    includes[:ext_management_systems][:hosts][:storages] = :tags unless options[:exclude_storages]
    MiqPreloader.preload(zone, includes)

    targets = zone.ems_clusters + zone.non_clustered_hosts
    targets += zone.storages.select { |s| Storage::SUPPORTED_STORAGE_TYPES.include?(s.store_type) } unless options[:exclude_storages]

    targets = targets.select { |t| t.perf_capture_enabled? }
    targets = targets.collect { |t| t.kind_of?(EmsCluster) ? t.hosts : t }.flatten

    targets += capture_vm_targets(targets, Host, options)

    targets
  end

  def self.capture_cloud_targets(zone, options = {})
    # things to worry about
    # 1) need to find all the VMs under all the availability zones
    # 2) need to find all the VMs that may not be in an availability zone
    # 3) cloudy clusters?
    targets = []

    includes = {:availability_zones => {:tags => {}}}
    MiqPreloader.preload(zone.ems_clouds, includes)

    targets += capture_vm_targets(zone.availability_zones, AvailabilityZone, options)

    # Unlike in the infra world--where every VM must be on a Host--in the cloud
    #   world (at least in OpenStack) some VMs might not be in an availability
    #   zone ... in fact, the out-of-the-box setting in nova for the default
    #   availability zone applied to new VMs is <NONE>.
    # Track down those cloudy VMs that have no availability zone
    targets += zone.vms_without_availability_zone unless options[:exclude_vms]
    targets
  end

  def self.capture_vm_targets(targets, parent_class, options = {})
    vms = []
    unless options[:exclude_vms]
      enabled_parents = targets.select do |t|
        t.kind_of?(parent_class) &&
          t.kind_of?(Metric::CiMixin) &&
          t.perf_capture_enabled? &&
          t.respond_to?(:vms)
      end
      MiqPreloader.preload(enabled_parents, :vms)
      vms = targets.collect { |t| enabled_parents.include?(t) ? t.vms.select { |v| v.state == 'on' } : [] }.flatten.compact
    end
    vms
  end

  # If a Cluster, standalone Host, or Storage is not enabled, skip it.
  # If a Cluster is enabled, capture all of its Hosts.
  # If a Host is enabled, capture all of its Vms.
  def self.capture_targets(zone = nil, options = {})
    zone = MiqServer.my_server.zone(true) if zone.nil?
    zone = Zone.find(zone) if zone.kind_of?(Integer)
    return capture_infra_targets(zone, options) + capture_cloud_targets(zone, options)
  end
end
