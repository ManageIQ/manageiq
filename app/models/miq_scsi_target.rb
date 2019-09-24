class MiqScsiTarget < ApplicationRecord
  serialize :address

  belongs_to :guest_device
  has_many :miq_scsi_luns, :dependent => :destroy

  def self.display_name(number = 1)
    n_('SCSI Target', 'SCSI Targets', number)
  end
end
