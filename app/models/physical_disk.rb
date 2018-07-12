class PhysicalDisk < ApplicationRecord
  belongs_to :physical_storage, :foreign_key => :physical_storage_id, :inverse_of => :physical_disks

  acts_as_miq_taggable
end
