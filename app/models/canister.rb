class Canister < ApplicationRecord
  belongs_to :physical_storage, :foreign_key => :physical_storage_id, :inverse_of => :canisters

  has_one :computer_system, :as => :managed_entity, :dependent => :destroy, :inverse_of => false
  has_one :hardware, :through => :computer_system

  has_many :guest_devices, :through => :hardware
  has_many :physical_network_ports, :through => :guest_devices

  acts_as_miq_taggable
end
