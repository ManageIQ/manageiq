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

  after_save :clear_my_region_cache

  acts_as_miq_taggable
  include AuthenticationMixin
  include UuidMixin
  include NamingSequenceMixin
  include AggregationMixin
  include ConfigurationManagementMixin

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
  AUTHENTICATION_TYPE  = "system_api".freeze

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
    miq_servers.where(:status => "started")
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
      _log.info "Cleared [#{rows}] rows from table [#{t}]"
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

  def ems_datawarehouses
    ext_management_systems.select { |e| e.kind_of? ManageIQ::Providers::DatawarehouseManager }
  end

  def ems_configproviders
    ext_management_systems.select { |e| e.kind_of? ManageIQ::Providers::ConfigurationManager }
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
    ::Settings.webservices.contactwith == 'hostname' ? remote_ws_hostname : remote_ws_ipaddress
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
    hostname && URI::HTTPS.build(:host => hostname).to_s
  end

  def generate_auth_key_queue(ssh_user, ssh_password, ssh_host = nil)
    args = [ssh_user, MiqPassword.try_encrypt(ssh_password)]
    args << ssh_host if ssh_host

    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :queue_name  => "generic",
      :method_name => "generate_auth_key",
      :args        => args
    )
  end

  def generate_auth_key(ssh_user, ssh_password, ssh_host = remote_ws_address)
    key = remote_region_v2_key(ssh_user, MiqPassword.try_decrypt(ssh_password), ssh_host)

    auth = AuthToken.new
    auth.auth_key = key
    auth.name = "Region #{region} API Key"
    auth.resource = self
    auth.authtype = AUTHENTICATION_TYPE
    auth.save!
  end

  def remove_auth_key
    authentication_delete(AUTHENTICATION_TYPE)
  end

  def verify_credentials(_auth_type = nil, _options = nil)
    # TODO: verify the key against the remote api using the api client gem
    true
  end

  def auth_key_configured?
    authentication_token(AUTHENTICATION_TYPE).present?
  end

  def api_system_auth_token(userid)
    token_hash = {
      :server_guid => remote_ws_miq_server.guid,
      :userid      => userid,
      :timestamp   => Time.now.utc
    }
    encrypt(token_hash.to_yaml)
  end

  def required_credential_fields(_type)
    [:auth_key]
  end

  def encrypt(string)
    region_v2_key = authentication_token(AUTHENTICATION_TYPE)
    raise "No key configured for region #{region}. Configure Central Admin to fetch the key" if region_v2_key.nil?

    file = Tempfile.new("region_auth_key")
    begin
      file.write(region_v2_key)
      file.close
      key = EzCrypto::Key.load(file.path)
      MiqPassword.new.encrypt(string, "v2", key)
    ensure
      file.unlink
    end
  end

  def self.api_system_auth_token_for_region(region_id, user)
    find_by_region(region_id).api_system_auth_token(user)
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

  private

  def clear_my_region_cache
    MiqRegion.my_region_clear_cache
  end

  def remote_region_v2_key(ssh_user, ssh_password, ssh_host)
    require 'net/scp'
    key_path = "/var/www/miq/vmdb/certs/v2_key"
    Net::SCP.download!(ssh_host, ssh_user, key_path, nil, :ssh => {:password => ssh_password})
  end
end
