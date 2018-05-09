class PhysicalNetworkPort < ApplicationRecord
  belongs_to :guest_device
  belongs_to :physical_switch
end
