class MiqScsiLun < ActiveRecord::Base
  belongs_to :miq_scsi_target

  include ReportableMixin
end


