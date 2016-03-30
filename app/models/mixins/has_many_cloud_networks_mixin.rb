module HasManyCloudNetworksMixin
  extend ActiveSupport::Concern

  # TODO(lsmola) NetworkManager, change this once we have a full representation of the NetworkManager, now we are
  # showing everything under CloudManager
  included do
    has_one :network_manager,
            :foreign_key => :parent_ems_id,
            :class_name  => "ManageIQ::Providers::Openstack::NetworkManager",
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

    before_validation :ensure_managers

    private

    def ensure_managers
      build_network_manager unless network_manager
      network_manager.name    = "#{name} Network Manager"
      network_manager.zone_id = zone_id
    end
  end
end
