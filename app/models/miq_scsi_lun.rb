class MiqScsiLun < ApplicationRecord
  belongs_to :miq_scsi_target

  include ReportableMixin
end
