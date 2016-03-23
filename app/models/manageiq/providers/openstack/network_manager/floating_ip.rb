class ManageIQ::Providers::Openstack::NetworkManager::FloatingIp < ::FloatingIp
  # TODO(lsmola) NetworkManager, move to the base class when all providers share the new network architecture
  has_one :vm, :through => :network_port, :source => :device, :source_type => "VmOrTemplate"

  def self.available
    where(:network_port_id => nil)
  end
end
