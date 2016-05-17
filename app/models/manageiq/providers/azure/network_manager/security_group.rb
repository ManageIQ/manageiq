class ManageIQ::Providers::Azure::NetworkManager::SecurityGroup < ::SecurityGroup
  has_many :vms, -> { distinct }, :through => :network_ports, :source => :device, :source_type => 'VmOrTemplate'
end
