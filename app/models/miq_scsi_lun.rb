class MiqScsiLun < ApplicationRecord
  belongs_to :miq_scsi_target

  def self.display_name(number = 1)
    n_('SCSI LUN', 'SCSI LUNs', number)
  end
end
