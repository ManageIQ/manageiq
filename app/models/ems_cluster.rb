class EmsCluster < ApplicationRecord
  include SupportsFeatureMixin
  include NewWithTypeStiMixin
  include_concern 'CapacityPlanning'
  include EventMixin
  include TenantIdentityMixin
  include CustomActionsMixin

  acts_as_miq_taggable

  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many    :hosts, :dependent => :nullify
  has_many    :vms_and_templates, :dependent => :nullify
  has_many    :miq_templates, :inverse_of => :ems_cluster
  has_many    :vms, :inverse_of => :ems_cluster

  has_many    :metrics,                :as => :resource  # Destroy will be handled by purger
  has_many    :metric_rollups,         :as => :resource  # Destroy will be handled by purger
  has_many    :vim_performance_states, :as => :resource  # Destroy will be handled by purger

  has_many    :policy_events, -> { order("timestamp") }
  has_many    :miq_events,         :as => :target,   :dependent => :destroy
  has_many    :miq_alert_statuses, :as => :resource, :dependent => :destroy

  virtual_column :v_ram_vr_ratio,      :type => :float,   :uses => [:aggregate_memory, :aggregate_vm_memory]
  virtual_column :v_cpu_vr_ratio,      :type => :float,   :uses => [:aggregate_cpu_total_cores, :aggregate_vm_cpus]
  virtual_column :v_parent_datacenter, :type => :string,  :uses => :all_relationships
  virtual_column :v_qualified_desc,    :type => :string,  :uses => :all_relationships
  virtual_total  :total_vms,               :vms
  virtual_total  :total_miq_templates,     :miq_templates
  virtual_total  :total_vms_and_templates, :vms_and_templates
  virtual_total  :total_hosts,             :hosts

  virtual_has_many :storages,       :uses => {:hosts => :storages}
  virtual_has_many :resource_pools, :uses => :all_relationships
  virtual_has_many :lans,           :uses => {:hosts => :lans}

  has_many :failover_hosts, -> { failover }, :class_name => "Host"

  include SerializedEmsRefObjMixin
  include ProviderObjectMixin

  include FilterableMixin

  include DriftStateMixin
  virtual_delegate :last_scan_on, :to => "last_drift_state_timestamp_rec.timestamp", :allow_nil => true

  include RelationshipMixin
  self.default_relationship_type = "ems_metadata"

  include AggregationMixin

  include Metric::CiMixin
  include MiqPolicyMixin
  include AsyncDeleteMixin

  #
  # Provider Object methods
  #
  # TODO: Vmware specific - Fix when we subclass EmsCluster

  def provider_object(connection)
    raise NotImplementedError unless ext_management_system.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
    connection.getVimClusterByMor(ems_ref_obj)
  end

  def provider_object_release(handle)
    raise NotImplementedError unless ext_management_system.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
    handle.release if handle rescue nil
  end

  #
  # Virtual Column methods
  #

  def v_ram_vr_ratio
    total_memory = aggregate_memory.to_f
    total_memory == 0 ? 0 : (aggregate_vm_memory / total_memory * 10).round * 0.1
  end

  def v_cpu_vr_ratio
    total_cpus = aggregate_cpu_total_cores.to_f
    total_cpus == 0 ? 0 : (aggregate_vm_cpus / total_cpus * 10).round * 0.1
  end

  def v_parent_datacenter
    dc = parent_datacenter
    dc.nil? ? "" : dc.name
  end

  def v_qualified_desc
    dc = parent_datacenter
    dc.nil? ? name : "#{name} in #{dc.name}"
  end

  delegate :my_zone, :to => :ext_management_system

  def total_vcpus
    hosts.inject(0) { |c, h| c + (h.total_vcpus || 0) }
  end

  #
  # Relationship methods
  #

  alias_method :storages,               :all_storages
  alias_method :datastores,             :all_storages    # Used by web-services to return datastores as the property name

  # Direct Vm relationship methods
  def direct_vm_rels
    # Look for only the Vms at the second depth (default RP + 1)
    descendant_rels(:of_type => 'VmOrTemplate').select { |r| (r.depth - depth) == 2 }
  end

  def direct_vms
    Relationship.resources(direct_vm_rels).sort_by { |v| v.name.downcase }
  end

  alias_method :direct_miq_templates, :miq_templates

  def direct_vms_and_templates
    (direct_vms + direct_miq_templates).sort_by { |v| v.name.downcase }
  end

  def direct_vm_ids
    Relationship.resource_ids(direct_vm_rels)
  end

  alias_method :direct_miq_template_ids, :miq_template_ids

  def direct_vm_or_template_ids
    direct_vm_ids + direct_miq_template_ids
  end

  virtual_total :total_direct_vms, :direct_vm_rels
  virtual_total :total_direct_miq_templates, :direct_miq_templates

  def total_direct_vms_and_templates
    total_direct_vms + total_direct_miq_templates
  end

  # Resource Pool relationship methods
  def default_resource_pool
    Relationship.resource(child_rels(:of_type => 'ResourcePool').first)
  end

  def resource_pools
    Relationship.resources(grandchild_rels(:of_type => 'ResourcePool'))
  end

  def resource_pools_with_default
    Relationship.resources(child_and_grandchild_rels(:of_type => 'ResourcePool'))
  end

  alias_method :add_resource_pool, :set_child
  alias_method :remove_resource_pool, :remove_child

  def remove_all_resource_pools
    remove_all_children(:of_type => 'ResourcePool')
  end

  # All RPs under this Cluster and all child RPs
  def all_resource_pools
    # descendants typically returns the default_rp first but sporadically it
    # will not due to a bug in the ancestry gem, this means we cannot simply
    # drop the first value and need to check is_default
    descendants(:of_type => 'ResourcePool').select { |r| !r.is_default }.sort_by { |r| r.name.downcase }
  end

  def all_resource_pools_with_default
    descendants(:of_type => 'ResourcePool').sort_by { |r| r.name.downcase }
  end

  # Parent relationship methods
  def parent_folder
    detect_ancestor(:of_type => "EmsFolder") { |a| !a.kind_of?(Datacenter) && !%w(host vm).include?(a.name) } # TODO: Fix this to use EmsFolder#hidden?
  end

  def parent_datacenter
    detect_ancestor(:of_type => 'EmsFolder') { |a| a.kind_of?(Datacenter) }
  end

  def event_where_clause(assoc = :ems_events)
    return ["ems_cluster_id = ?", id] if assoc.to_sym == :policy_events

    cond = ["ems_cluster_id = ?"]
    cond_params = [id]

    ids = all_host_ids
    unless ids.empty?
      cond << "host_id IN (?) OR dest_host_id IN (?)"
      cond_params += [ids, ids]
    end

    ids = all_vm_or_template_ids
    unless ids.empty?
      cond << "vm_or_template_id IN (?) OR dest_vm_or_template_id IN (?)"
      cond_params += [ids, ids]
    end

    cond_params.unshift(cond.join(" OR ")) unless cond.empty?
    cond_params
  end

  def ems_events
    ewc = event_where_clause
    return [] if ewc.blank?
    EmsEvent.where(ewc).order("timestamp").to_a
  end

  def scan(_userid = "system")
    MiqQueue.submit_job(
      :service     => "smartstate",
      :affinity    => ext_management_system,
      :class_name  => self.class.to_s,
      :method_name => "save_drift_state",
      :instance_id => id,
    )
  end

  def get_reserve(field)
    rp = default_resource_pool
    rp && rp.send(field)
  end

  def cpu_reserve
    get_reserve(:cpu_reserve)
  end

  def memory_reserve
    get_reserve(:memory_reserve)
  end

  def effective_resource(resource)
    resource = resource.to_s
    unless %w(cpu vcpu memory).include?(resource)
      raise ArgumentError, _("Unknown resource %{name}") % {:name => resource.inspect}
    end
    resource = "cpu" if resource == "vcpu"
    send("effective_#{resource}")
  end

  #
  # Metric methods
  #

  PERF_ROLLUP_CHILDREN = :hosts

  def perf_rollup_parents(interval_name = nil)
    [ext_management_system].compact unless interval_name == 'realtime'
  end

  def self.get_perf_collection_object_list
    cl_hash = in_my_region.includes(:tags, :taggings).select(:id, :name).each_with_object({}) do |c, h|
      h[c.id] = {:cl_rec => c, :ho_ids => c.host_ids}
    end

    hids = cl_hash.values.flat_map { |v| v[:ho_ids] }.compact.uniq
    hosts_by_id = Host.where(:id => hids).includes(:tags, :taggings).select(:id, :name).index_by(&:id)

    cl_hash.each do |_k, v|
      hosts = hosts_by_id.values_at(*v[:ho_ids]).compact
      if hosts.empty?
        v[:ho_enabled] = v[:ho_disabled] = []
      else
        v[:ho_enabled], v[:ho_disabled] = hosts.partition(&:perf_capture_enabled?)
      end
    end

    cl_hash
  end

  def get_perf_collection_object_list
    hosts = hosts_enabled_for_perf_capture
    self.perf_capture_enabled? ? [self] + hosts : hosts
  end

  def perf_capture_enabled_host_ids=(ids)
    self.perf_capture_enabled = ids.any?
    hosts.each { |h| h.perf_capture_enabled = ids.include?(h.id) }
  end

  def hosts_enabled_for_perf_capture
    hosts(:include => [:taggings, :tags]).select(&:perf_capture_enabled?)
  end

  # Vmware specific
  def register_host(host)
    host = Host.extract_objects(host)
    raise _("Host cannot be nil") if host.nil?
    userid, password = host.auth_user_pwd(:default)
    network_address  = host.address

    with_provider_object do |vim_cluster|
      begin
        _log.info("Invoking addHost with options: address => #{network_address}, #{userid}")
        host_mor = vim_cluster.addHost(network_address, userid, password)
      rescue VimFault => verr
        fault = verr.vimFaultInfo.fault
        raise if     fault.nil?
        raise unless fault.xsiType == "SSLVerifyFault"

        ssl_thumbprint = fault.thumbprint
        _log.info("Invoking addHost with options: address => #{network_address}, userid => #{userid}, sslThumbprint => #{ssl_thumbprint}")
        host_mor = vim_cluster.addHost(network_address, userid, password, :sslThumbprint => ssl_thumbprint)
      end

      host.ems_ref                = host_mor
      host.ems_ref_obj            = host_mor
      host.ext_management_system  = ext_management_system
      host.save!
      hosts << host
      host.refresh_ems
    end
  end

  cache_with_timeout(:node_types) do
    if !openstack_clusters_exists?
      :non_openstack
    elsif non_openstack_clusters_exists?
      :mixed_clusters
    else
      :openstack
    end
  end

  def self.openstack_clusters_exists?
    ems = ManageIQ::Providers::Openstack::InfraManager.pluck(:id)
    ems.empty? ? false : EmsCluster.where(:ems_id => ems).exists?
  end

  def self.non_openstack_clusters_exists?
    ems = ManageIQ::Providers::Openstack::InfraManager.pluck(:id)
    EmsCluster.where.not(:ems_id => ems).exists?
  end

  def openstack_cluster?
    ext_management_system.class == ManageIQ::Providers::Openstack::InfraManager
  end

  def self.display_name(number = 1)
    n_('Cluster / Deployment Role', 'Clusters / Deployment Roles', number)
  end
end
