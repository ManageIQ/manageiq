module ManageIQ::Providers
  class InfraManager < BaseManager
    require_nested :Cluster
    require_nested :Datacenter
    require_nested :Folder
    require_nested :MetricsCapture
    require_nested :ProvisionWorkflow
    require_nested :ResourcePool
    require_nested :Storage
    require_nested :StorageCluster
    require_nested :Template
    require_nested :Vm
    require_nested :VmOrTemplate

    include AvailabilityMixin

    has_many :distributed_virtual_switches, :dependent => :destroy, :foreign_key => :ems_id, :inverse_of => :ext_management_system
    has_many :distributed_virtual_lans, -> { distinct }, :through => :distributed_virtual_switches, :source => :lans
    has_many :host_virtual_switches, -> { distinct }, :through => :hosts
    has_many :host_virtual_lans, -> { distinct }, :through => :hosts

    has_many :host_hardwares,             :through => :hosts, :source => :hardware
    has_many :host_operating_systems,     :through => :hosts, :source => :operating_system
    has_many :host_storages,              :through => :hosts
    has_many :host_switches,              :through => :hosts
    has_many :host_networks,              :through => :hosts, :source => :networks
    has_many :host_guest_devices,         :through => :host_hardwares, :source => :guest_devices
    has_many :host_disks,                 :through => :host_hardwares, :source => :disks
    has_many :snapshots,                  :through => :vms_and_templates
    has_many :switches, -> { distinct },  :through => :hosts
    has_many :lans, -> { distinct },      :through => :hosts
    has_many :subnets, -> { distinct },   :through => :lans
    has_many :networks,                   :through => :hardwares
    has_many :guest_devices,              :through => :hardwares
    has_many :ems_custom_attributes,      :through => :vms_and_templates
    has_many :clusterless_hosts, -> { where(:ems_cluster =>nil) }, :class_name => "Host", :foreign_key => "ems_id", :inverse_of => :ext_management_system

    include HasManyOrchestrationStackMixin

    class << model_name
      define_method(:route_key) { "ems_infras" }
      define_method(:singular_route_key) { "ems_infra" }
    end

    #
    # ems_timeouts is a general purpose proc for obtaining
    # read and open timeouts for any ems type and optional service.
    #
    # :ems
    #   :ems_redhat    (This is the type parameter for these methods)
    #     :open_timeout: 3.minutes
    #     :inventory   (This is the optional service parameter for ems_timeouts)
    #        :read_timeout: 5.minutes
    #     :service
    #        :read_timeout: 1.hour
    #
    def self.ems_timeouts(type, service = nil)
      ems_settings = ::Settings.ems[type]
      return [nil, nil] unless ems_settings

      service = service.try(:downcase)
      read_timeout = ems_settings.fetch_path([service, :read_timeout].compact).try(:to_i_with_method)
      open_timeout = ems_settings.fetch_path([service, :open_timeout].compact).try(:to_i_with_method)
      [read_timeout, open_timeout]
    end

    def validate_authentication_status
      {:available => true, :message => nil}
    end
  end

  def self.display_name(number = 1)
    n_('Infrastructure Manager', 'Infrastructure Managers', number)
  end
end
