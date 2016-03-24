class ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet < ::CloudSubnet
  belongs_to :network_router, :class_name => "ManageIQ::Providers::Amazon::NetworkManager::NetworkRouter"
end
