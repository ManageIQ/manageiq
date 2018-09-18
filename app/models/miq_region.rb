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

  virtual_has_many :vms_and_templates
  virtual_has_many :miq_templates
  virtual_has_many :vms

  after_save :clear_my_region_cache

  acts_as_miq_taggable
  include UuidMixin
  include NamingSequenceMixin
  include AggregationMixin
  include ConfigurationManagementMixin

  include MiqPolicyMixin
  include SupportsFeatureMixin
  include Metric::CiMixin

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

  def servers_for_settings_reload
    # This method is used to queue reload_settings for the resources which
    # had settings changed.  If those servers are in a different region it is
    # not possible to queue methods for them so we want to filter the
    # returned servers to just ones in the current region.
    miq_servers.in_my_region.where(:status => "started")
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
      raise Exception,
            _("Region [%{region_id}] does not match the database's region [%{db_id}]") % {:region_id => my_region_id,
                                                                                          :db_id     => db_region_id}
    end

    create_with(:description => "Region #{my_region_id}").find_or_create_by!(:region => my_region_id) do
      _log.info("Creating Region [#{my_region_id}]")
    end
  end

  def self.destroy_region(conn, region, tables = nil)
    tables ||= (conn.tables - MiqPglogical::ALWAYS_EXCLUDED_TABLES).sort
    tables.each do |t|
      pk = conn.primary_key(t)
      if pk
        conditions = sanitize_conditions(region_to_conditions(region, pk))
      else
        id_cols = connection.columns(t).select { |c| c.name.ends_with?("_id") }
        next if id_cols.empty?
        conditions = id_cols.collect { |c| "(#{sanitize_conditions(region_to_conditions(region, c.name))})" }.join(" OR ")
      end

      rows = conn.delete("DELETE FROM #{t} WHERE #{conditions}")
      _log.info("Cleared [#{rows}] rows from table [#{t}]")
    end
  end

  def self.remote_replication_type?
    MiqPglogical.new.provider?
  end

  def self.global_replication_type?
    MiqPglogical.new.subscriber?
  end

  def self.replication_enabled?
    MiqPglogical.new.node?
  end

  def self.replication_type
    if global_replication_type?
      :global
    elsif remote_replication_type?
      :remote
    else
      :none
    end
  end

  def self.replication_type=(desired_type)
    current_type = replication_type
    return desired_type if desired_type == current_type

    MiqPglogical.new.destroy_provider   if current_type == :remote
    PglogicalSubscription.delete_all    if current_type == :global
    MiqPglogical.new.configure_provider if desired_type == :remote
    # Do nothing to add a global
    desired_type
  end

  def ems_clouds
    ext_management_systems.select { |e| e.kind_of?(EmsCloud) }
  end

  def ems_infras
    ext_management_systems.select { |e| e.kind_of?(EmsInfra) }
  end

  def ems_containers
    ext_management_systems.select { |e| e.kind_of?(ManageIQ::Providers::ContainerManager) }
  end

  def ems_middlewares
    ext_management_systems.select { |e| e.kind_of?(ManageIQ::Providers::MiddlewareManager) }
  end

  def ems_datawarehouses
    ext_management_systems.select { |e| e.kind_of?(ManageIQ::Providers::DatawarehouseManager) }
  end

  def ems_monitors
    ext_management_systems.select { |e| e.kind_of?(ManageIQ::Providers::MonitoringManager) }
  end

  def ems_configproviders
    ext_management_systems.select { |e| e.kind_of?(ManageIQ::Providers::ConfigurationManager) }
  end

  def assigned_roles
    miq_servers.eager_load(:server_roles).collect(&:assigned_roles).flatten.uniq.compact
  end

  def role_active?(role_name)
    active_miq_servers.any? { |s| s.has_active_role?(role_name) }
  end

  def role_assigned?(role_name)
    active_miq_servers.any? { |s| s.has_assigned_role?(role_name) }
  end

  def remote_ui_miq_server
    MiqServer.in_region(region).recently_active.find_by(:has_active_userinterface => true)
  end

  def remote_ui_ipaddress
    server = remote_ui_miq_server
    server.try(:ipaddress)
  end

  def remote_ui_hostname
    server = remote_ui_miq_server
    server && (server.hostname || server.ipaddress)
  end

  def remote_ui_url(contact_with = :hostname)
    svr = remote_ui_miq_server
    remote_ui_url_override = svr.settings_for_resource.ui.url if svr
    return remote_ui_url_override if remote_ui_url_override

    hostname = send("remote_ui_#{contact_with}")
    hostname && "https://#{hostname}"
  end

  def remote_ws_miq_server
    MiqServer.in_region(region).recently_active.find_by(:has_active_webservices => true)
  end

  def remote_ws_address
    ::Settings.webservices.contactwith == 'hostname' ? remote_ws_hostname : remote_ws_ipaddress
  end

  def remote_ws_ipaddress
    miq_server = remote_ws_miq_server
    miq_server.try(:ipaddress)
  end

  def remote_ws_hostname
    miq_server = remote_ws_miq_server
    miq_server && (miq_server.hostname || miq_server.ipaddress)
  end

  def remote_ws_url
    svr = remote_ws_miq_server
    remote_url_override = svr.settings_for_resource.webservices.url if svr
    return remote_url_override if remote_url_override

    hostname = remote_ws_address
    hostname && URI::HTTPS.build(:host => hostname).to_s
  end

  def api_system_auth_token(userid)
    token_hash = {
      :server_guid => remote_ws_miq_server.guid,
      :userid      => userid,
      :timestamp   => Time.now.utc
    }
    MiqPassword.encrypt(token_hash.to_yaml)
  end

  def self.api_system_auth_token_for_region(region_id, user)
    find_by_region(region_id).api_system_auth_token(user)
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
    raise _("options should be a Hash of type => enabled") unless options.kind_of?(Hash)
    unless options.keys.all? { |k| VALID_CAPTURE_ALWAYS_TYPES.include?(k.to_sym) }
      raise _("options are invalid, all keys must be one of %{type}") % {:type => VALID_CAPTURE_ALWAYS_TYPES.inspect}
    end
    unless options.values.all? { |v| [true, false].include?(v) }
      raise _("options are invalid, all values must be one of [true, false]")
    end

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

  def self.display_name(number = 1)
    n_('Region', 'Regions', number)
  end

  private

  def clear_my_region_cache
    MiqRegion.my_region_clear_cache
  end
end
