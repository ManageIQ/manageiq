class EmsCluster < ActiveRecord::Base
  include_concern 'CapacityPlanning'
  include ReportableMixin
  include EventMixin

  acts_as_miq_taggable

  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many    :hosts
  has_many    :vms_and_templates
  has_many    :miq_templates
  has_many    :vms

  has_many    :metrics,                :as => :resource  # Destroy will be handled by purger
  has_many    :metric_rollups,         :as => :resource  # Destroy will be handled by purger
  has_many    :vim_performance_states, :as => :resource  # Destroy will be handled by purger

  has_many    :policy_events,          :dependent => :nullify, :order => "timestamp"

  virtual_column :v_ram_vr_ratio,      :type => :float,   :uses => [:aggregate_memory, :aggregate_vm_memory]
  virtual_column :v_cpu_vr_ratio,      :type => :float,   :uses => [:aggregate_logical_cpus, :aggregate_vm_cpus]
  virtual_column :v_parent_datacenter, :type => :string,  :uses => :all_relationships
  virtual_column :v_qualified_desc,    :type => :string,  :uses => :all_relationships
  virtual_column :last_scan_on,        :type => :time,    :uses => :last_drift_state_timestamp
  virtual_column :total_vms,           :type => :integer, :uses => :all_relationships
  virtual_column :total_miq_templates, :type => :integer, :uses => :all_relationships
  virtual_column :total_hosts,         :type => :integer, :uses => :all_relationships

  virtual_has_many :storages,       :uses => {:hosts => :storages}
  virtual_has_many :resource_pools, :uses => :all_relationships
  virtual_has_many :failover_hosts, :uses => :hosts

  virtual_has_many :base_storage_extents, :class_name => "CimStorageExtent"
  virtual_has_many :storage_systems,      :class_name => "CimComputerSystem"
  virtual_has_many :file_shares,          :class_name => 'SniaFileShare'
  virtual_has_many :storage_volumes,      :class_name => 'CimStorageVolume'

  include SerializedEmsRefObjMixin
  include ProviderObjectMixin

  include FilterableMixin

  include DriftStateMixin
  alias last_scan_on last_drift_state_timestamp

  include RelationshipMixin
  self.default_relationship_type = "ems_metadata"

  include AggregationMixin
  # Since we've overridden the implementation of methods from AggregationMixin,
  # we must also override the :uses portion of the virtual columns.
  override_aggregation_mixin_virtual_columns_uses(:all_hosts, :hosts)
  override_aggregation_mixin_virtual_columns_uses(:all_vms_and_templates, :vms_and_templates)

  include Metric::CiMixin
  include MiqPolicyMixin
  include AsyncDeleteMixin
  include WebServiceAttributeMixin

  #
  # Provider Object methods
  #
  # TODO: Vmware specific - Fix when we subclass EmsCluster

  def provider_object(connection)
    raise NotImplementedError unless self.ext_management_system.kind_of?(EmsVmware)
    connection.getVimClusterByMor(self.ems_ref_obj)
  end

  def provider_object_release(handle)
    raise NotImplementedError unless self.ext_management_system.kind_of?(EmsVmware)
    handle.release if handle rescue nil
  end

  #
  # Virtual Column methods
  #

  def v_ram_vr_ratio
    total_memory = self.aggregate_memory.to_f
    return total_memory == 0 ? 0 : (self.aggregate_vm_memory / total_memory * 10).round * 0.1
  end

  def v_cpu_vr_ratio
    total_cpus = self.aggregate_logical_cpus.to_f
    return total_cpus == 0 ? 0 : (self.aggregate_vm_cpus / total_cpus * 10).round * 0.1
  end

  def v_parent_datacenter
    dc = self.parent_datacenter
    dc.nil? ? "" : dc.name
  end

  def v_qualified_desc
    dc = self.parent_datacenter
    dc.nil? ? self.name : "#{self.name} in #{dc.name}"
  end

  def my_zone
    self.ext_management_system.my_zone
  end

  def total_vcpus
    self.hosts.inject(0) {|c,h| c + (h.total_vcpus || 0)}
  end

  #
  # Relationship methods
  #

  alias storages               all_storages
  alias datastores             all_storages    # Used by web-services to return datastores as the property name

  alias all_hosts              hosts
  alias all_host_ids           host_ids
  alias all_vms_and_templates  vms_and_templates
  alias all_vm_or_template_ids vm_or_template_ids
  alias all_vms                vms
  alias all_vm_ids             vm_ids
  alias all_miq_templates      miq_templates
  alias all_miq_template_ids   miq_template_ids

  # Host relationship methods
  def total_hosts
    self.hosts.size
  end

  def failover_hosts(options = {})
    self.hosts.select(&:failover)
  end

  def failover_host_ids
    self.failover_hosts.collect(&:id)
  end

  # Direct Vm relationship methods
  def direct_vm_rels
    # Look for only the Vms at the second depth (default RP + 1)
    self.descendant_rels(:of_type => 'VmOrTemplate').select { |r| (r.depth - self.depth) == 2 }
  end

  def direct_vms
    Relationship.resources(direct_vm_rels).sort_by { |v| v.name.downcase }
  end

  alias direct_miq_templates miq_templates

  def direct_vms_and_templates
    (direct_vms + direct_miq_templates).sort_by { |v| v.name.downcase }
  end

  def direct_vm_ids
    Relationship.resource_ids(direct_vm_rels)
  end

  alias direct_miq_template_ids miq_template_ids

  def direct_vm_or_template_ids
    direct_vm_ids + direct_miq_template_ids
  end

  def total_direct_vms
    direct_vm_rels.size
  end

  def total_direct_miq_templates
    direct_miq_template_ids.size
  end

  def total_direct_vms_and_templates
    total_direct_vms + total_direct_miq_templates
  end

  # All VMs under this Cluster
  def total_vms
    vms.size
  end

  def total_miq_templates
    miq_templates.size
  end

  def total_vms_and_templates
    vms_and_templates.size
  end

  # Resource Pool relationship methods
  def default_resource_pool
    Relationship.resource(self.child_rels(:of_type => 'ResourcePool').first)
  end

  def resource_pools
    # Look for only the resource_pools at the second depth (default depth + 1)
    rels = self.descendant_rels(:of_type => 'ResourcePool')
    min_depth = rels.collect { |r| r.depth }.min
    rels = rels.select { |r| r.depth == min_depth + 1 }
    Relationship.resources(rels).sort_by { |r| r.name.downcase }
  end

  def resource_pools_with_default
    # Look for only the resource_pools up to the second depth (default depth + 1)
    rels = self.descendant_rels(:of_type => 'ResourcePool')
    min_depth = rels.collect { |r| r.depth }.min
    rels = rels.select { |r| r.depth <= min_depth + 1 }
    Relationship.resources(rels).sort_by { |r| r.name.downcase }
  end

  alias add_resource_pool set_child
  alias remove_resource_pool remove_child

  def remove_all_resource_pools
    self.remove_all_children(:of_type => 'ResourcePool')
  end

  # All RPs under this Cluster and all child RPs
  def all_resource_pools
    self.descendants(:of_type => 'ResourcePool')[1..-1].sort_by { |r| r.name.downcase }
  end

  def all_resource_pools_with_default
    self.descendants(:of_type => 'ResourcePool').sort_by { |r| r.name.downcase }
  end

  # Parent relationship methods
  def parent_folder
    self.detect_ancestor(:of_type => "EmsFolder") { |a| !a.is_datacenter && !["host", "vm"].include?(a.name) } # TODO: Fix this to use EmsFolder#hidden?
  end

  def parent_datacenter
    self.detect_ancestor(:of_type => 'EmsFolder') { |a| a.is_datacenter }
  end

  def base_storage_extents
    all_hosts.collect { |h| h.base_storage_extents }.flatten.uniq
  end

  def storage_systems
    all_hosts.collect { |h| h.storage_systems }.flatten.uniq
  end

  def storage_volumes
    all_hosts.collect { |h| h.storage_volumes }.flatten.uniq
  end

  def file_shares
    all_hosts.collect { |h| h.file_shares }.flatten.uniq
  end

  def event_where_clause(assoc=:ems_events)
    return ["ems_cluster_id = ?", self.id] if assoc.to_sym == :policy_events

    cond = ["ems_cluster_id = ?"]
    cond_params = [self.id]

    ids = self.all_host_ids
    unless ids.empty?
      cond << "host_id IN (?) OR dest_host_id IN (?)"
      cond_params += [ids, ids]
    end

    ids = self.all_vm_or_template_ids
    unless ids.empty?
      cond << "vm_or_template_id IN (?) OR dest_vm_or_template_id IN (?)"
      cond_params += [ids, ids]
    end

    cond_params.unshift(cond.join(" OR ")) unless cond.empty?
    return cond_params
  end

  def ems_events
    ewc = self.event_where_clause
    return [] if ewc.blank?
    EmsEvent.find(:all, :conditions => ewc, :order => "timestamp")
  end

  def scan
    zone = self.ext_management_system ? self.ext_management_system.my_zone : nil
    MiqQueue.put(:class_name=>self.class.to_s, :method_name=>"save_drift_state", :instance_id=>self.id, :zone => zone, :role => "smartstate")
  end

  def get_reserve(field)
    rp = self.default_resource_pool
    rp.nil? ? nil : rp.send(field)
  end

  def cpu_reserve
    get_reserve(:cpu_reserve)
  end

  def memory_reserve
    get_reserve(:memory_reserve)
  end

  def effective_resource(resource)
    resource = resource.to_s
    raise ArgumentError, "Unknown resource #{resource.inspect}" unless %w{cpu vcpu memory}.include?(resource)
    resource = "cpu" if resource == "vcpu"
    self.send("effective_#{resource}")
  end

  #
  # Metric methods
  #

  PERF_ROLLUP_CHILDREN = :hosts

  def perf_rollup_parent(interval_name=nil)
    self.ext_management_system unless interval_name == 'realtime'
  end

  def self.get_perf_collection_object_list
    # cl_hash = self.in_my_region.all(:include => [:tags, :taggings, :ext_management_system], :select => "name, id, ems_id").inject({}) do |h,c|
      cl_hash = self.in_my_region.all(:include => [:tags, :taggings], :select => "name, id").inject({}) do |h,c|
      h[c.id] = {:cl_rec => c, :ho_ids => c.host_ids}
      h
    end

    hids = cl_hash.collect do |a|
      k, v = a
      v[:ho_ids]
    end.flatten.compact.uniq

    hosts_by_id = Host.find_all_by_id(hids, :include => [:tags, :taggings], :select => "name, id").inject({}) { |h,host| h[host.id] = host; h }

    cl_hash.each do |k,v|
      hosts = hosts_by_id.values_at(*v[:ho_ids]).compact
      unless hosts.empty?
        v[:ho_enabled], v[:ho_disabled] = hosts.partition { |h| h.perf_capture_enabled? }
      else
        v[:ho_enabled] = v[:ho_disabled] = []
      end
    end

    return cl_hash
  end

  def get_perf_collection_object_list
    hosts = self.hosts_enabled_for_perf_capture
    self.perf_capture_enabled? ? [self] + hosts : hosts
  end

  def set_perf_collection_object_list(list)
    ([self] + self.hosts).each { |obj| obj.perf_capture_enabled = list.include?(obj) }
  end

  def hosts_enabled_for_perf_capture
    self.hosts(:include => [:taggings, :tags]).select { |h| h.perf_capture_enabled? }
  end

  # Vmware specific
  def register_host(host)
    log_header = "MIQ(EmsCluster.register_host)"
    host = Host.extract_objects(host)
    raise "Host cannot be nil" if host.nil?
    userid, password = host.auth_user_pwd(:default)
    network_address  = host.address

    with_provider_object do |vim_cluster|
      begin
        $log.info "#{log_header} Invoking addHost with options: address => #{network_address}, #{userid}"
        host_mor = vim_cluster.addHost(network_address, userid, password)
      rescue VimFault => verr
        fault = verr.vimFaultInfo.fault
        raise if     fault.nil?
        raise unless fault.xsiType == "SSLVerifyFault"

        ssl_thumbprint = fault.thumbprint
        $log.info "#{log_header} Invoking addHost with options: address => #{network_address}, userid => #{userid}, sslThumbprint => #{ssl_thumbprint}"
        host_mor = vim_cluster.addHost(network_address, userid, password, :sslThumbprint => ssl_thumbprint)
      end

      host.ems_ref                = host_mor
      host.ems_ref_obj            = host_mor
      host.ext_management_system  = self.ext_management_system
      host.save!
      self.hosts << host
      host.refresh_ems
    end
  end
end
