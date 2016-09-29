class CloudSubnetNetworkPort < ApplicationRecord
  include DtoMixin

  dto_dependencies :cloud_subnets, :network_ports
  dto_manager_ref :address, :cloud_subnet, :network_port
  dto_attributes :address, :cloud_subnet, :network_port

  self.table_name = "cloud_subnets_network_ports"

  belongs_to :cloud_subnet
  belongs_to :network_port
end
