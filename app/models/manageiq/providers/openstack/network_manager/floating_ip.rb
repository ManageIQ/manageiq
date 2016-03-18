class ManageIQ::Providers::Openstack::NetworkManager::FloatingIp < ::FloatingIp
  has_one :vm, :through => :network_port, :as => :device

  # TODO(lsmola) NetworkManager, once all providers use network manager we don't need this
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
end
