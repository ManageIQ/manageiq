class FirmwareBinaryFirmwareTarget < ApplicationRecord
  self.table_name = 'firmware_binaries_firmware_targets'

  belongs_to :firmware_binary
  belongs_to :firmware_target
end
