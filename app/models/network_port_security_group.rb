class NetworkPortSecurityGroup < ApplicationRecord
  self.table_name = "network_ports_security_groups"

  belongs_to :network_port
  belongs_to :security_group
end
