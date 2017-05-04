module HasNetworkManagerMixin
  extend ActiveSupport::Concern

  included do
    has_one :network_manager,
            :foreign_key => :parent_ems_id,
            :class_name  => "ManageIQ::Providers::NetworkManager",
            :autosave    => true,
            :dependent   => :destroy

    delegate :floating_ips,
             :security_groups,
             :cloud_networks,
             :cloud_subnets,
             :network_ports,
             :network_routers,
             :public_networks,
             :private_networks,
             :all_cloud_networks,
             :to        => :network_manager,
             :allow_nil => true

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
