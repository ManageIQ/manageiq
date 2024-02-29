class PhysicalDisk < ApplicationRecord
  belongs_to :physical_storage, :inverse_of => :physical_disks
  belongs_to :canister, :inverse_of => :physical_disks

  acts_as_miq_taggable
end
