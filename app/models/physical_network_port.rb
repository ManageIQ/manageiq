class PhysicalNetworkPort < ApplicationRecord
  belongs_to :guest_device
  belongs_to :physical_switch, :foreign_key => :switch_id, :inverse_of => :physical_network_ports

  has_one :connected_port, :foreign_key => "connected_port_uid", :primary_key => "uid_ems", :class_name => "PhysicalNetworkPort", :dependent => :nullify, :inverse_of => :connected_port
  has_one :connected_physical_switch, :through => :connected_port, :source => :physical_switch
  has_one :computer_system, :through => :guest_device
  has_one :connected_computer_system, :through => :connected_port, :source => :computer_system

  alias_attribute :name, :port_name
end
