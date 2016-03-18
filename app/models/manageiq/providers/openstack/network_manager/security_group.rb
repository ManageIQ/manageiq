class ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup < ::SecurityGroup
  # TODO(lsmola) NetworkManager, once all providers use network manager we don't need this
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
end
