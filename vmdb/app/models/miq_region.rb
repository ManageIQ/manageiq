class MiqRegion < ActiveRecord::Base
  has_many :zones,                  :finder_sql => lambda { |_| Zone.in_region(region_number).to_sql }
  has_many :ext_management_systems, :finder_sql => lambda { |_| ExtManagementSystem.in_region(region_number).to_sql }
  has_many :vms_and_templates,      :finder_sql => lambda { |_| VmOrTemplate.in_region(region_number).to_sql }
  has_many :vms,                    :finder_sql => lambda { |_| Vm.in_region(region_number).to_sql }
  has_many :miq_templates,          :finder_sql => lambda { |_| MiqTemplate.in_region(region_number).to_sql }
  has_many :hosts,                  :finder_sql => lambda { |_| Host.in_region(region_number).to_sql }
  has_many :storages,               :finder_sql => lambda { |_| Storage.in_region(region_number).to_sql }
  has_many :policy_events,          :finder_sql => lambda { |_| PolicyEvent.in_region(region_number).to_sql }
  has_many :miq_servers,            :finder_sql => lambda { |_| MiqServer.in_region(region_number).to_sql }
  has_many :active_miq_servers,     :finder_sql => lambda { |_| MiqServer.in_region(region_number).where(:status => ['started', 'starting']).to_sql }, :class_name => "MiqServer"

  has_many :database_backups, :finder_sql => lambda { |_| DatabaseBackup.in_region(region_number).to_sql }

  has_many :metrics,        :as => :resource # Destroy will be handled by purger
  has_many :metric_rollups, :as => :resource # Destroy will be handled by purger
  has_many :vim_performance_states, :as => :resource # Destroy will be handled by purger

  acts_as_miq_taggable
  include ReportableMixin
  include UuidMixin

  include AggregationMixin
  # Since we've overridden the implementation of methods from AggregationMixin,
  # we must also override the :uses portion of the virtual columns.
  override_aggregation_mixin_virtual_columns_uses(:all_hosts, :hosts)
  override_aggregation_mixin_virtual_columns_uses(:all_vms_and_templates, :vms_and_templates)

  include MiqPolicyMixin
  include Metric::CiMixin

  alias all_vms_and_templates  vms_and_templates
  alias all_vm_or_template_ids vm_or_template_ids
  alias all_vms                vms
  alias all_vm_ids             vm_ids
  alias all_miq_templates      miq_templates
  alias all_miq_template_ids   miq_template_ids
  alias all_hosts              hosts
  alias all_host_ids           host_ids
  alias all_storages           storages

  PERF_ROLLUP_CHILDREN = [:ext_management_systems, :storages]

  def perf_rollup_parent(interval_name=nil)
    MiqEnterprise.my_enterprise unless interval_name == 'realtime'
  end

  def my_zone
    MiqServer.my_zone
  end

  def name
    self.description
  end

  def find_master_server
    active_miq_servers.detect(&:is_master?)
  end

  def self.my_region
    self.where(:region => self.my_region_number).first
  end

  def self.seed
    # Get the region by looking at an existing MiqDatabase instance's id
    # (ie, 2000000000001 is region 2) and sync this to the file
    my_region = self.my_region_number
    db = MiqDatabase.first
    if db
      region = db.region_id
      raise Exception, "Region [#{my_region}] does not match the database's region [#{region}]" if region != my_region
    end

    unless self.exists?(:region => my_region)
      $log.info("MIQ(MiqRegion.seed) Creating Region [#{my_region}]")
      self.create!(:region => my_region, :description => "Region #{my_region}")
      $log.info("MIQ(MiqRegion.seed) Creating Region... Complete")
    end
  end

  def self.sync_with_db_region(config = false)
    # Establish a connection to a different database so that we can sync with the new DB's region
    if config
      raise "Failed to retrieve database configuration for Rails.env [#{Rails.env}] in config with keys: #{config.keys.inspect}" unless config.has_key?(Rails.env)
      $log.info("MIQ(#{self.name}.#{__method__}) establishing connection with #{config[Rails.env].merge("password" => "[PASSWORD]").inspect}")
      MiqDatabase.establish_connection(config[Rails.env])
    end

    db = MiqDatabase.first
    return if db.nil?

    my_region = self.my_region_number(true)
    region = db.region_id
    if region != my_region
      $log.info("MIQ(MiqRegion.sync_new_db_region) Changing region file from: [#{my_region}] to: [#{region}]... restart to use new region")
      MiqRegion.sync_region_to_file(region)
    end
  end

  def self.sync_region_to_file(region)
    File.open(File.join(Rails.root, "REGION"), "w") {|f| f.write region }
  end

  def ems_clouds
    self.ext_management_systems.select {|e| e.kind_of? EmsCloud }
  end

  def ems_infras
    self.ext_management_systems.select {|e| e.kind_of? EmsInfra }
  end

  def assigned_roles
    self.miq_servers.collect { |s| s.assigned_roles }.flatten.uniq.compact
  end

  def role_active?(role_name)
    self.active_miq_servers.any? {|s| s.has_active_role?(role_name) }
  end

  def role_assigned?(role_name)
    self.active_miq_servers.any? {|s| s.has_assigned_role?(role_name) }
  end

  def remote_ui_miq_server
    MiqServer.in_region(self.region).where(:has_active_userinterface => true).first
  end

  def remote_ui_ipaddress
    server = self.remote_ui_miq_server
    server.nil? ? nil : server.ipaddress
  end

  def remote_ui_hostname
    server = self.remote_ui_miq_server
    server.nil? ? nil : (server.hostname || server.ipaddress)
  end

  def remote_ui_url(contact_with = :hostname)
    hostname = self.send("remote_ui_#{contact_with}")
    return hostname.nil? ? nil : "https://#{hostname}"
  end

  def remote_ws_miq_server
    MiqServer.in_region(self.region).where(:has_active_webservices => true).first
  end

  def remote_ws_address
    contact_with = VMDB::Config.new("vmdb").config.fetch_path(:webservices, :contactwith)
    contact_with == 'hostname' ? self.remote_ws_hostname : self.remote_ws_ipaddress
  end

  def remote_ws_ipaddress
    miq_server = self.remote_ws_miq_server
    miq_server.nil? ? nil : miq_server.ipaddress
  end

  def remote_ws_hostname
    miq_server = self.remote_ws_miq_server
    miq_server.nil? ? nil : (miq_server.hostname || miq_server.ipaddress)
  end

  def remote_ws_url
    hostname = self.remote_ws_address
    return hostname.nil? ? nil : "https://#{hostname}"
  end

  #
  # Region atStartup - log all management systems
  #

  def self.atStartup
    region = self.my_region
    prefix = "MIQ(MiqRegion.atStartup) Region: [#{region.region}], name: [#{region.name}]"
    self.log_under_management(prefix)
    self.log_not_under_management(prefix)
  end

  def self.log_under_management(prefix)
    total_vms     = 0
    total_hosts   = 0
    total_sockets = 0

    ExtManagementSystem.all(:order => :id).each do |e|
      vms     = e.all_vms_and_templates.count
      hosts   = e.all_hosts.count
      sockets = e.aggregate_physical_cpus
      $log.info("#{prefix}, EMS: [#{e.id}], Name: [#{e.name}], IP Address: [#{e.ipaddress}], Hostname: [#{e.hostname}], VMs: [#{vms}], Hosts: [#{hosts}], Sockets: [#{sockets}]")

      total_vms     += vms
      total_hosts   += hosts
      total_sockets += sockets
    end
    $log.info("#{prefix}, Under Management: VMs: [#{total_vms}], Hosts: [#{total_hosts}], Sockets: [#{total_sockets}]")
  end

  def self.log_not_under_management(prefix)
    hosts_objs = Host.where(:ems_id => nil)
    hosts      = hosts_objs.count
    vms        = VmOrTemplate.count(:conditions =>  {:ems_id => nil})
    sockets    = self.my_region.aggregate_physical_cpus(hosts_objs)
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
      enable ? self.tag_add('capture_enabled', :ns => ns) : self.tag_with('', :ns => ns)
    end

    # Clear tag association cache instead of full reload.
    association_cache.except!(:tags, :taggings)

    # Set @perf_capture_always since we already know all the answers
    options = options.dup
    (VALID_CAPTURE_ALWAYS_TYPES - options.keys).each do |type|
      options[type] = self.is_tagged_with?("capture_enabled", :ns => "/performance/#{type}")
    end
    @perf_capture_always = options.freeze
  end
end
