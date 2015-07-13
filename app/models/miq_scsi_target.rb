class MiqScsiTarget < ActiveRecord::Base
  serialize :address

  belongs_to :guest_device
  has_many :miq_scsi_luns, :dependent => :destroy
end
