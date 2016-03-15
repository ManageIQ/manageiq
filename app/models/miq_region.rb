class MiqRegion < ApplicationRecord
  has_many :metrics,        :as => :resource # Destroy will be handled by purger
  has_many :metric_rollups, :as => :resource # Destroy will be handled by purger
  has_many :vim_performance_states, :as => :resource # Destroy will be handled by purger

  virtual_has_many :database_backups,       :class_name => "DatabaseBackup"
  virtual_has_many :ext_management_systems, :class_name => "ExtManagementSystem"
  virtual_has_many :hosts,                  :class_name => "Host"
  virtual_has_many :storages,               :class_name => "Storage"
  virtual_has_many :policy_events,          :class_name => "PolicyEvent"
  virtual_has_many :zones,                  :class_name => "Zone"

  virtual_has_many :miq_servers,            :class_name => "MiqServer"
  virtual_has_many :active_miq_servers,     :class_name => "MiqServer"

  virtual_has_many :vms_and_templates,      :uses => :all_relationships
  virtual_has_many :miq_templates,          :uses => :all_relationships
  virtual_has_many :vms,                    :uses => :all_relationships

  acts_as_miq_taggable
  include ReportableMixin
  include UuidMixin
  include NamingSequenceMixin
  include AggregationMixin
  # Since we've overridden the implementation of methods from AggregationMixin,
  # we must also override the :uses portion of the virtual columns.
  override_aggregation_mixin_virtual_columns_uses(:all_hosts, :hosts)
  override_aggregation_mixin_virtual_columns_uses(:all_vms_and_templates, :vms_and_templates)

  include MiqPolicyMixin
  include Metric::CiMixin

  alias_method :all_vms_and_templates,  :vms_and_templates
  alias_method :all_vm_or_template_ids, :vm_or_template_ids
  alias_method :all_vms,                :vms
  alias_method :all_vm_ids,             :vm_ids
  alias_method :all_miq_templates,      :miq_templates
  alias_method :all_miq_template_ids,   :miq_template_ids
  alias_method :all_hosts,              :hosts
  alias_method :all_host_ids,           :host_ids
  alias_method :all_storages,           :storages

  PERF_ROLLUP_CHILDREN = [:ext_management_systems, :storages]

  def database_backups
    DatabaseBackup.in_region(region_number)
  end

  def ext_management_systems
    ExtManagementSystem.in_region(region_number)
  end

  def hosts
    Host.in_region(region_number)
  end

  def storages
    Storage.in_region(region_number)
  end

  def policy_events
    PolicyEvent.in_region(region_number)
  end

  def zones
    Zone.in_region(region_number)
  end

  def miq_servers
    MiqServer.in_region(region_number)
  end

  def active_miq_servers
    MiqServer.in_region(region_number).active_miq_servers
  end

  def vms_and_templates
    VmOrTemplate.in_region(region_number)
  end

  def miq_templates
    MiqTemplate.in_region(region_number)
  end

  def vms
    Vm.in_region(region_number)
  end

  def perf_rollup_parents(interval_name = nil)
    [MiqEnterprise.my_enterprise].compact unless interval_name == 'realtime'
  end

  def my_zone
    MiqServer.my_zone
  end

  def name
    description
  end

  def find_master_server
    active_miq_servers.detect(&:is_master?)
  end

  cache_with_timeout(:my_region) { find_by(:region => my_region_number) }

  def self.seed
    # Get the region by looking at an existing MiqDatabase instance's id
    # (ie, 2000000000001 is region 2) and sync this to the file
    my_region_id = my_region_number
    db_region_id = MiqDatabase.first.try(:region_id)
    if db_region_id && db_region_id != my_region_id
      raise Exception, "Region [#{my_region_id}] does not match the database's region [#{db_region_id}]"
    end

    create_with(:description => "Region #{my_region_id}").find_or_create_by!(:region => my_region_id) do
      _log.info("Creating Region [#{my_region_id}]")
    end
  end

  def self.destroy_region(conn, region, tables = nil)
    tables ||= conn.tables.reject { |t| t =~ /^schema_migrations|^ar_internal_metadata|^rr/ }.sort
    tables.each do |t|
      pk = conn.primary_key(t)
      if pk
        conditions = sanitize_conditions(region_to_conditions(region, pk))
      else
        id_cols = connection.columns(t).select { |c| c.name.ends_with?("_id") }
        conditions = id_cols.collect { |c| "(#{sanitize_conditions(region_to_conditions(region, c.name))})" }.join(" OR ")
      end

      rows = conn.delete("DELETE FROM #{t} WHERE #{conditions}")
      _log.info "Cleared [#{rows}] rows from table [#{t}]"
    end
  end

  def ems_clouds
    ext_management_systems.select { |e| e.kind_of? EmsCloud }
  end

  def ems_infras
    ext_management_systems.select { |e| e.kind_of? EmsInfra }
  end

  def ems_containers
    ext_management_systems.select { |e| e.kind_of? ManageIQ::Providers::ContainerManager }
  end

  def ems_middlewares
    ext_management_systems.select { |e| e.kind_of? ManageIQ::Providers::MiddlewareManager }
  end

  def assigned_roles
    miq_servers.collect(&:assigned_roles).flatten.uniq.compact
  end

  def role_active?(role_name)
    active_miq_servers.any? { |s| s.has_active_role?(role_name) }
  end

  def role_assigned?(role_name)
    active_miq_servers.any? { |s| s.has_assigned_role?(role_name) }
  end

  def remote_ui_miq_server
    MiqServer.in_region(region).find_by(:has_active_userinterface => true)
  end

  def remote_ui_ipaddress
    server = remote_ui_miq_server
    server.nil? ? nil : server.ipaddress
  end

  def remote_ui_hostname
    server = remote_ui_miq_server
    server.nil? ? nil : (server.hostname || server.ipaddress)
  end

  def remote_ui_url(contact_with = :hostname)
    hostname = send("remote_ui_#{contact_with}")
    hostname.nil? ? nil : "https://#{hostname}"
  end

  def remote_ws_miq_server
    MiqServer.in_region(region).find_by(:has_active_webservices => true)
  end

  def remote_ws_address
    contact_with = VMDB::Config.new("vmdb").config.fetch_path(:webservices, :contactwith)
    contact_with == 'hostname' ? remote_ws_hostname : remote_ws_ipaddress
  end

  def remote_ws_ipaddress
    miq_server = remote_ws_miq_server
    miq_server.nil? ? nil : miq_server.ipaddress
  end

  def remote_ws_hostname
    miq_server = remote_ws_miq_server
    miq_server.nil? ? nil : (miq_server.hostname || miq_server.ipaddress)
  end

  def remote_ws_url
    hostname = remote_ws_address
    hostname.nil? ? nil : "https://#{hostname}"
  end

  #
  # Region atStartup - log all management systems
  #

  def self.atStartup
    region = my_region
    prefix = "#{_log.prefix} Region: [#{region.region}], name: [#{region.name}]"
    log_under_management(prefix)
    log_not_under_management(prefix)
  end

  def self.log_under_management(prefix)
    total_vms     = 0
    total_hosts   = 0
    total_sockets = 0

    ExtManagementSystem.all.each do |e|
      vms     = e.all_vms_and_templates.count
      hosts   = e.all_hosts.count
      sockets = e.aggregate_physical_cpus
      $log.info("#{prefix}, EMS: [#{e.id}], Name: [#{e.name}], IP Address: [#{e.ipaddress}], Hostname: [#{e.hostname}], VMs: [#{vms}], Hosts: [#{hosts}], Sockets: [#{sockets}]")

      total_vms += vms
      total_hosts += hosts
      total_sockets += sockets
    end
    $log.info("#{prefix}, Under Management: VMs: [#{total_vms}], Hosts: [#{total_hosts}], Sockets: [#{total_sockets}]")
  end

  def self.log_not_under_management(prefix)
    hosts_objs = Host.where(:ems_id => nil)
    hosts      = hosts_objs.count
    vms        = VmOrTemplate.where(:ems_id => nil).count
    sockets    = my_region.aggregate_physical_cpus(hosts_objs)
    $log.info("#{prefix}, Not Under Management: VMs: [#{vms}], Hosts: [#{hosts}], Sockets: [#{sockets}]")
  end

  #
  # Region level metric capture always methods
  #

  VALID_CAPTURE_ALWAYS_TYPES = [:storage, :host_and_cluster]

  def perf_capture_always
    @perf_capture_always ||= VALID_CAPTURE_ALWAYS_TYPES.each_with_object({}) do |type, h|
      h[type] = self.is_tagged_with?("capture_enabled", :ns => "/performance/#{type}")
    end.freeze
  end

  def perf_capture_always=(options)
    raise "options should be a Hash of type => enabled" unless options.kind_of?(Hash)
    raise "options are invalid, all keys must be one of #{VALID_CAPTURE_ALWAYS_TYPES.inspect}" unless options.keys.all? { |k| VALID_CAPTURE_ALWAYS_TYPES.include?(k.to_sym) }
    raise "options are invalid, all values must be one of [true, false]" unless options.values.all? { |v| [true, false].include?(v) }

    options.each do |type, enable|
      ns = "/performance/#{type}"
      enable ? tag_add('capture_enabled', :ns => ns) : tag_with('', :ns => ns)
    end

    # Clear tag association cache instead of full reload.
    @association_cache.except!(:tags, :taggings)

    # Set @perf_capture_always since we already know all the answers
    options = options.dup
    (VALID_CAPTURE_ALWAYS_TYPES - options.keys).each do |type|
      options[type] = self.is_tagged_with?("capture_enabled", :ns => "/performance/#{type}")
    end
    @perf_capture_always = options.freeze
  end
end
