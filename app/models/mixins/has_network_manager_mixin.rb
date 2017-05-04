module HasNetworkManagerMixin
  extend ActiveSupport::Concern

  included do
    has_one :network_manager,
            :foreign_key => :parent_ems_id,
            :class_name  => "ManageIQ::Providers::NetworkManager",
            :autosave    => true,
            :dependent   => :destroy

    has_many :floating_ips,    :through => :network_manager
    has_many :security_groups, :through => :network_manager
    has_many :cloud_networks,  :through => :network_manager
    has_many :cloud_subnets,   :through => :network_manager
    has_many :network_ports,   :through => :network_manager
    has_many :network_routers, :through => :network_manager

    alias_method :all_cloud_networks, :cloud_networks

    private

    def ensure_managers
      ensure_network_manager
      network_manager.name = "#{name} Network Manager"
      ensure_managers_zone_and_provider_region
    end

    def ensure_managers_zone_and_provider_region
      if network_manager
        network_manager.zone_id         = zone_id
        network_manager.provider_region = provider_region
      end
    end
  end
end
