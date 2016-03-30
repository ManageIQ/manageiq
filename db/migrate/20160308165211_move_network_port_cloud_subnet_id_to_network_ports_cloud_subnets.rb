class MoveNetworkPortCloudSubnetIdToNetworkPortsCloudSubnets < ActiveRecord::Migration[5.0]
  class NetworkPort < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class CloudSubnet < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class CloudSubnetNetworkPort < ActiveRecord::Base
    self.table_name = "cloud_subnets_network_ports"
    self.inheritance_column = :_type_disabled
  end

  def up
    # Move NetworkPort belongs_to :cloud_subnet to NetworkPort has_many :cloud_subnets, :through => :cloud_subnet_network_port
    NetworkPort.find_each do |network_port|
      CloudSubnetNetworkPort.create!(
        :cloud_subnet_id => network_port.cloud_subnet_id,
        :network_port_id => network_port.id)
    end
  end

  def down
    # Move NetworkPort belongs_to :cloud_subnet to NetworkPort has_many :cloud_subnets, :through => :cloud_subnet_network_port
    NetworkPort.find_each do |network_port|
      cloud_subnet_network_port = CloudSubnetNetworkPort.find_by(:network_port_id => network_port.id)
      if cloud_subnet_network_port
        network_port.update_attributes!(:cloud_subnet_id => cloud_subnet_network_port.cloud_subnet_id)
        cloud_subnet_network_port.destroy
      end
    end
  end
end
