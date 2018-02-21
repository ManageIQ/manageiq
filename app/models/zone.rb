class Zone < ApplicationRecord
  validates_presence_of   :name, :description
  validates :name, :unique_within_region => true

  serialize :settings, Hash

  belongs_to      :log_file_depot, :class_name => "FileDepot"

  has_many :miq_servers
  has_many :ext_management_systems
  has_many :container_managers, :class_name => "ManageIQ::Providers::ContainerManager"
  has_many :miq_schedules, :dependent => :destroy
  has_many :ldap_regions
  has_many :providers

  has_many :hosts,                 :through => :ext_management_systems
  has_many :clustered_hosts,       :through => :ext_management_systems
  has_many :non_clustered_hosts,   :through => :ext_management_systems
  has_many :vms_and_templates,     :through => :ext_management_systems
  has_many :vms,                   :through => :ext_management_systems
  has_many :miq_templates,         :through => :ext_management_systems
  has_many :ems_clusters,          :through => :ext_management_systems
  has_many :container_nodes,       :through => :container_managers
  has_many :container_groups,      :through => :container_managers
  has_many :container_replicators, :through => :container_managers
  has_many :containers,            :through => :container_managers
  virtual_has_many :active_miq_servers, :class_name => "MiqServer"

  before_destroy :check_zone_in_use_on_destroy

  include AuthenticationMixin

  include SupportsFeatureMixin
  include Metric::CiMixin
  include AggregationMixin
  include ConfigurationManagementMixin

  def active_miq_servers
    MiqServer.active_miq_servers.where(:zone_id => id)
  end

  def servers_for_settings_reload
    miq_servers.where(:status => "started")
  end

  def find_master_server
    active_miq_servers.detect(&:is_master?)
  end

  def self.seed
    create_with(:description => "Default Zone").find_or_create_by!(:name => 'default') do |_z|
      _log.info("Creating default zone...")
    end
  end

  def miq_region
    MiqRegion.find_by(:region => region_id)
  end

  def assigned_roles
    miq_servers.flat_map(&:assigned_roles).uniq.compact
  end

  def role_active?(role_name)
    active_miq_servers.any? { |s| s.has_active_role?(role_name) }
  end

  def role_assigned?(role_name)
    active_miq_servers.any? { |s| s.has_assigned_role?(role_name) }
  end

  def active_role_names
    miq_servers.flat_map(&:active_role_names).uniq
  end

  def self.default_zone
    find_by(:name => "default")
  end

  def remote_cockpit_ws_miq_server
    role_active?("cockpit_ws") ? miq_servers.find_by(:has_active_cockpit_ws => true) : nil
  end

  # The zone to use when inserting a record into MiqQueue
  def self.determine_queue_zone(options)
    if options.key?(:zone)
      options[:zone] # return specified zone including nil (aka ANY zone)
    elsif options[:role] && ServerRole.regional_role?(options[:role])
      nil # ANY zone, will be limited by role
    else
      MiqServer.my_zone
    end
  end

  def synchronize_logs(*args)
    active_miq_servers.each { |s| s.synchronize_logs(*args) }
  end

  def last_log_sync_on
    miq_servers.inject(nil) do |d, s|
      last = s.last_log_sync_on
      d ||= last
      d = last if last && last > d
      d
    end
  end

  def log_collection_active?
    miq_servers.any?(&:log_collection_active?)
  end

  def log_collection_active_recently?(since = nil)
    miq_servers.any? { |s| s.log_collection_active_recently?(since) }
  end

  def self.hosts_without_a_zone
    Host.where(:ems_id => nil).to_a
  end

  def self.clusters_without_a_zone
    EmsCluster.where(:ems_id => nil).to_a
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

  def middleware_servers
    ems_middlewares.flat_map(&:middleware_servers)
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

  def ems_clouds
    ext_management_systems.select { |e| e.kind_of?(EmsCloud) }
  end

  def ems_networks
    ext_management_systems.select { |e| e.kind_of?(ManageIQ::Providers::NetworkManager) }
  end

  def availability_zones
    MiqPreloader.preload(ems_clouds, :availability_zones)
    ems_clouds.flat_map(&:availability_zones)
  end

  def self.vms_without_a_zone
    Vm.where(:ems_id => nil).to_a
  end

  def storages
    MiqPreloader.preload(self, :ext_management_systems => {:hosts => :storages})
    ext_management_systems.flat_map(&:storages).uniq
  end

  def self.storages_without_a_zone
    storage_without_hosts = Storage.includes(:hosts).where(:host_storages => {:storage_id => nil}).to_a
    storage_without_ems = Host.where(:ems_id => nil).includes(:storages).flat_map(&:storages).uniq
    storage_without_hosts + storage_without_ems
  end

  def display_name
    name
  end

  def active?
    miq_servers.any?(&:active?)
  end

  def any_started_miq_servers?
    miq_servers.any?(&:started?)
  end

  def ntp_reload_queue
    servers = active_miq_servers
    return if servers.blank?
    _log.info("Zone: [#{name}], Queueing ntp_reload for [#{servers.length}] active_miq_servers, ids: #{servers.collect(&:id)}")

    servers.each(&:ntp_reload_queue)
  end

  protected

  def check_zone_in_use_on_destroy
    raise _("cannot delete default zone") if name == "default"
    raise _("zone name '%{name}' is used by a server") % {:name => name} unless miq_servers.blank?
  end
end
