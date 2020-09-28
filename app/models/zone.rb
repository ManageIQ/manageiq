class Zone < ApplicationRecord
  validates_presence_of   :name, :description
  validates :name, :unique_within_region => true

  serialize :settings, Hash

  belongs_to :log_file_depot, :class_name => "FileDepot"

  has_many :miq_servers
  has_many :ext_management_systems
  has_many :paused_ext_management_systems, :class_name => 'ExtManagementSystem', :foreign_key => :zone_before_pause_id
  has_many :container_managers, :class_name => "ManageIQ::Providers::ContainerManager"
  has_many :miq_schedules, :dependent => :destroy
  has_many :providers
  has_many :miq_queues, :dependent => :destroy, :foreign_key => :zone, :primary_key => :name

  has_many :hosts,                 :through => :ext_management_systems
  has_many :clustered_hosts,       :through => :ext_management_systems
  has_many :non_clustered_hosts,   :through => :ext_management_systems
  has_many :vms_and_templates,     :through => :ext_management_systems
  has_many :vms,                   :through => :ext_management_systems
  has_many :miq_templates,         :through => :ext_management_systems
  has_many :ems_clusters,          :through => :ext_management_systems
  has_many :physical_servers,      :through => :ext_management_systems
  has_many :storages,              :through => :ext_management_systems
  has_many :container_nodes,       :through => :container_managers
  has_many :container_groups,      :through => :container_managers
  has_many :container_replicators, :through => :container_managers
  has_many :containers,            :through => :container_managers
  has_many :host_hardwares, :class_name => 'Hardware', :through => :hosts, :source => :hardware
  has_many :vm_hardwares, :class_name => 'Hardware', :through => :vms_and_templates, :source => :hardware
  virtual_has_many :active_miq_servers, :class_name => "MiqServer"

  before_destroy :remove_servers_if_podified
  before_destroy :check_zone_in_use_on_destroy
  after_create :create_server_if_podified

  include AuthenticationMixin

  include SupportsFeatureMixin
  include Metric::CiMixin
  include AggregationMixin
  include ConfigurationManagementMixin

  scope :visible, -> { where(:visible => true) }
  default_value_for :visible, true

  def active_miq_servers
    MiqServer.active_miq_servers.where(:zone_id => id)
  end

  def servers_for_settings_reload
    miq_servers.where(:status => "started")
  end

  def find_master_server
    active_miq_servers.detect(&:is_master?)
  end

  def self.create_maintenance_zone
    return MiqRegion.my_region.maintenance_zone if MiqRegion.my_region.maintenance_zone.present?

    begin
      # 1) Create Maintenance zone
      zone = create!(:name        => "__maintenance__#{SecureRandom.uuid}",
                     :description => "Maintenance Zone",
                     :visible     => false)

      # 2) Assign to MiqRegion
      MiqRegion.my_region.update(:maintenance_zone => zone)
    rescue ActiveRecord::RecordInvalid
      raise if zone.errors[:name].blank?
      retry
    end
    _log.info("Creating maintenance zone...")
    zone
  end

  private_class_method :create_maintenance_zone

  def self.seed
    MiqRegion.seed
    create_maintenance_zone

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
    in_my_region.find_by(:name => "default")
  end

  # Zone for paused providers (no servers in it), not visible by default
  cache_with_timeout(:maintenance_zone) do
    MiqRegion.my_region&.maintenance_zone
  end

  def remote_cockpit_ws_miq_server
    miq_servers.find_by(:has_active_cockpit_ws => true) if role_active?("cockpit_ws")
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
    options = args.extract_options!
    enabled = Settings.log.collection.include_automate_models_and_dialogs

    active_miq_servers.each_with_index do |s, index|
      # If enabled, export the automate domains and dialogs on the first active server
      include_models_and_dialogs = enabled ? index.zero? : false
      s.synchronize_logs(*args, options.merge(:include_automate_models_and_dialogs => include_models_and_dialogs))
    end
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

  # @return [Array<ExtManagementSystem>] All emses that can collect Capacity and Utilization metrics
  def ems_metrics_collectable
    ext_management_systems.select { |e| e.kind_of?(EmsCloud) || e.kind_of?(EmsInfra) || e.kind_of?(ManageIQ::Providers::ContainerManager) }
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

  def message_for_invalid_delete
    return _("cannot delete default zone") if name == "default"
    return _("cannot delete maintenance zone") if self == self.class.maintenance_zone
    return _("zone name '%{name}' is used by a server") % {:name => name} if !MiqEnvironment::Command.is_podified? && miq_servers.present?
    _("zone name '%{name}' is used by a provider") % {:name => name} if ext_management_systems.present?
  end

  protected

  def remove_servers_if_podified
    return unless MiqEnvironment::Command.is_podified?

    miq_servers.destroy_all
  end

  def create_server_if_podified
    return unless MiqEnvironment::Command.is_podified?
    return if name == "default" || !visible

    miq_servers.create!(:name => name)
  end

  def check_zone_in_use_on_destroy
    msg = message_for_invalid_delete
    raise msg if msg
  end
end
