class CloudSubnetNetworkPort < ApplicationRecord
  self.table_name = "cloud_subnets_network_ports"

  belongs_to :cloud_subnet
  belongs_to :network_port
end
