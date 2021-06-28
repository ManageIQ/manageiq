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
             :security_policies,
             :cloud_networks,
             :cloud_subnets,
             :network_ports,
             :network_routers,
             :network_services,
             :public_networks,
             :private_networks,
             :all_cloud_networks,
             :to        => :network_manager,
             :allow_nil => true

    alias_method :all_cloud_networks, :cloud_networks

    private

    def ensure_network_manager
      # TODO: remove name from here once all child classes
      network_manager || build_network_manager(:name => "#{name} Network Manager")
    end

    # TODO: remove and have each manager implement this
    def ensure_managers
      ensure_network_manager
      network_manager.name = "#{name} Network Manager" if network_manager
      ensure_managers_zone_and_provider_region
    end

    # TODO: remove and have each manager implement this
    def ensure_managers_zone_and_provider_region
      if network_manager
        propagate_child_manager_attributes(network_manager, "#{name} Network Manager")
      end
    end
  end
end
