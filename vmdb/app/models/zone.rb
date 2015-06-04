class Zone < ActiveRecord::Base
  DEFAULT_NTP_SERVERS = {:server => %w(0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org)}.freeze

  validates_presence_of   :name, :description
  validates_uniqueness_of :name

  serialize :settings, Hash

  belongs_to      :log_file_depot, :class_name => "FileDepot"
  alias_attribute :log_depot, :log_file_depot

  has_many :miq_servers
  has_many :active_miq_servers, :class_name => "MiqServer", :conditions => {:status => MiqServer::STATUSES_ACTIVE}
  has_many :ext_management_systems
  has_many :miq_groups, :as => :resource
  has_many :miq_schedules, :dependent => :destroy
  has_many :storage_managers
  has_many :ldap_regions
  has_many :providers

  virtual_has_many :hosts,             :uses => {:ext_management_systems => :hosts}
  virtual_has_many :vms_and_templates, :uses => {:ext_management_systems => :vms_and_templates}

  include ReportableMixin

  before_destroy :check_zone_in_use_on_destroy
  after_save     :queue_ntp_reload_if_changed

  include AuthenticationMixin

  include Metric::CiMixin
  include AggregationMixin
  # Since we've overridden the implementation of methods from AggregationMixin,
  # we must also override the :uses portion of the virtual columns.
  override_aggregation_mixin_virtual_columns_uses(:all_hosts, :hosts)
  override_aggregation_mixin_virtual_columns_uses(:all_vms_and_templates, :vms_and_templates)

  def find_master_server
    active_miq_servers.detect(&:is_master?)
  end

  def self.seed
    MiqRegion.my_region.lock do
      unless self.exists?(:name => 'default')
        $log.info("MIQ(Zone.seed) Creating default zone...")
        self.create(:name => "default", :description => "Default Zone")
        $log.info("MIQ(Zone.seed) Creating default zone... Complete")
      end
    end
  end

  def miq_region
    MiqRegion.where(:region => self.region_id).first
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
    self.active_miq_servers.any? {|s| s.has_active_role?(role_name) }
  end

  def role_assigned?(role_name)
    self.active_miq_servers.any? {|s| s.has_assigned_role?(role_name) }
  end

  def active_role_names
    miq_servers.flat_map(&:active_role_names).uniq
  end

  def self.default_zone
    self.where(:name => "default").first
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
    active_miq_servers.all.each { |s| s.synchronize_logs(*args) }
  end

  def last_log_sync_on
    self.miq_servers.inject(nil) do |d,s|
      last = s.last_log_sync_on
      d ||= last
      d = last if last && last > d
      d
    end
  end

  def log_collection_active?
    self.miq_servers.any?(&:log_collection_active?)
  end

  def log_collection_active_recently?(since = nil)
    self.miq_servers.any? { |s| s.log_collection_active_recently?(since) }
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
    self.ext_management_systems.select { |e| e.kind_of? EmsInfra }
  end

  def ems_containers
    ext_management_systems.select { |e| e.kind_of? EmsContainer }
  end

  def ems_clouds
    self.ext_management_systems.select { |e| e.kind_of? EmsCloud }
  end

  def availability_zones
    MiqPreloader.preload(self.ems_clouds, :availability_zones)
    ems_clouds.flat_map(&:availability_zones)
  end

  def vms_without_availability_zone
    MiqPreloader.preload(self, :ext_management_systems => :vms)
    ext_management_systems.flat_map do |e|
      e.kind_of?(EmsCloud) ? e.vms.select { |vm| vm.availability_zone.nil? } : []
    end
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
    storage_without_hosts = Storage.includes(:hosts).where(:hosts_storages => {:storage_id => nil}).to_a
    storage_without_ems = Host.where(:ems_id => nil).includes(:storages).flat_map(&:storages).uniq
    storage_without_hosts + storage_without_ems
  end

  # Used by AggregationMixin
  alias all_storages           storages
  alias all_hosts              hosts
  alias all_host_ids           host_ids
  alias all_vms_and_templates  vms_and_templates
  alias all_vm_or_template_ids vm_or_template_ids
  alias all_vms                vms
  alias all_vm_ids             vm_ids
  alias all_miq_templates      miq_templates
  alias all_miq_template_ids   miq_template_ids

  def display_name
    name
  end

  def active?
    miq_servers.any?(&:active?)
  end

  protected

  def check_zone_in_use_on_destroy
    raise "cannot delete default zone" if self.name == "default"
    raise "zone name '#{self.name}' is used by a server" unless self.miq_servers.blank?
  end

  private

  def queue_ntp_reload_if_changed
    return if settings_was[:ntp] == ntp_settings

    servers = active_miq_servers
    return if servers.blank?
    $log.info("MIQ(Zone#queue_ntp_reload) Zone: [#{name}], Queueing ntp_reload for [#{servers.length}] active_miq_servers, ids: #{servers.collect(&:id)}")

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
