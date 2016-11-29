class Zone < ApplicationRecord
  DEFAULT_NTP_SERVERS = {:server => %w(0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org)}.freeze

  validates_presence_of   :name, :description
  validates_uniqueness_of :name

  serialize :settings, Hash

  belongs_to      :log_file_depot, :class_name => "FileDepot"

  has_many :miq_servers
  has_many :ext_management_systems
  has_many :miq_schedules, :dependent => :destroy
  has_many :storage_managers
  has_many :ldap_regions
  has_many :providers

  virtual_has_many :hosts,              :uses => {:ext_management_systems => :hosts}
  virtual_has_many :active_miq_servers, :class_name => "MiqServer"
  virtual_has_many :vms_and_templates,  :uses => {:ext_management_systems => :vms_and_templates}

  before_destroy :check_zone_in_use_on_destroy
  after_save     :queue_ntp_reload_if_changed

  include AuthenticationMixin

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

  def ntp_settings
    # Return ntp settings if populated otherwise return the defaults  {:ntp => {:server => ['blah'], :timeout => 5}}
    return settings[:ntp] if settings.fetch_path(:ntp, :server).present?

    Zone::DEFAULT_NTP_SERVERS.dup
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

  def host_ids
    hosts.collect(&:id)
  end

  def hosts
    MiqPreloader.preload(self, :ext_management_systems => :hosts)
    ext_management_systems.flat_map(&:hosts)
  end

  def self.hosts_without_a_zone
    Host.where(:ems_id => nil).to_a
  end

  def non_clustered_hosts
    MiqPreloader.preload(self, :ext_management_systems => :hosts)
    ext_management_systems.flat_map(&:non_clustered_hosts)
  end

  def clustered_hosts
    MiqPreloader.preload(self, :ext_management_systems => :hosts)
    ext_management_systems.flat_map(&:clustered_hosts)
  end

  def ems_clusters
    MiqPreloader.preload(self, :ext_management_systems => :ems_clusters)
    ext_management_systems.flat_map(&:ems_clusters)
  end

  def self.clusters_without_a_zone
    EmsCluster.where(:ems_id => nil).to_a
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

  def middleware_servers
    ems_middlewares.flat_map(&:middleware_servers)
  end

  def ems_datawarehouses
    ext_management_systems.select { |e| e.kind_of? ManageIQ::Providers::DatawarehouseManager }
  end

  def ems_configproviders
    ext_management_systems.select { |e| e.kind_of? ManageIQ::Providers::ConfigurationManager }
  end

  def ems_clouds
    ext_management_systems.select { |e| e.kind_of? EmsCloud }
  end

  def ems_networks
    ext_management_systems.select { |e| e.kind_of? ManageIQ::Providers::NetworkManager }
  end

  def availability_zones
    MiqPreloader.preload(ems_clouds, :availability_zones)
    ems_clouds.flat_map(&:availability_zones)
  end

  def vms_and_templates
    MiqPreloader.preload(self, :ext_management_systems => :vms_and_templates)
    ext_management_systems.flat_map(&:vms_and_templates)
  end

  def vms
    MiqPreloader.preload(self, :ext_management_systems => :vms)
    ext_management_systems.flat_map(&:vms)
  end

  def self.vms_without_a_zone
    Vm.where(:ems_id => nil).to_a
  end

  def miq_templates
    MiqPreloader.preload(self, :ext_management_systems => :miq_templates)
    ext_management_systems.flat_map(&:miq_templates)
  end

  def vm_or_template_ids
    vms_and_templates.collect(&:id)
  end

  def vm_ids
    vms.collect(&:id)
  end

  def miq_template_ids
    miq_templates.collect(&:id)
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

  # Used by AggregationMixin
  alias_method :all_storages,           :storages
  alias_method :all_hosts,              :hosts
  alias_method :all_host_ids,           :host_ids
  alias_method :all_vms_and_templates,  :vms_and_templates
  alias_method :all_vm_or_template_ids, :vm_or_template_ids
  alias_method :all_vms,                :vms
  alias_method :all_vm_ids,             :vm_ids
  alias_method :all_miq_templates,      :miq_templates
  alias_method :all_miq_template_ids,   :miq_template_ids

  def display_name
    name
  end

  def active?
    miq_servers.any?(&:active?)
  end

  def any_started_miq_servers?
    miq_servers.any?(&:started?)
  end

  protected

  def check_zone_in_use_on_destroy
    raise _("cannot delete default zone") if name == "default"
    raise _("zone name '%{name}' is used by a server") % {:name => name} unless miq_servers.blank?
  end

  private

  def queue_ntp_reload_if_changed
    return if settings_was[:ntp] == ntp_settings

    servers = active_miq_servers
    return if servers.blank?
    _log.info("Zone: [#{name}], Queueing ntp_reload for [#{servers.length}] active_miq_servers, ids: #{servers.collect(&:id)}")

    servers.each do |s|
      MiqQueue.put(
        :class_name  => "MiqServer",
        :instance_id => s.id,
        :method_name => "ntp_reload",
        :args        => [ntp_settings],
        :server_guid => s.guid,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => name
      )
    end
  end
end
