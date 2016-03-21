class ManageIQ::Providers::Openstack::NetworkManager::FloatingIp < ::FloatingIp
  has_one :vm, :through => :network_port, :source => :device, :source_type => "VmOrTemplate"
end
