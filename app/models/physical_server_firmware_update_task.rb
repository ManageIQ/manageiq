class PhysicalServerFirmwareUpdateTask < MiqRequestTask
  include_concern 'StateMachine'

  validates :state, :inclusion => {
    :in      => %w[pending queued active firmware_updated finished],
    :message => 'should be pending, queued, active, firmware_updated or finished'
  }

  AUTOMATE_DRIVES = false

  def description
    'Physical Server Firmware Update'
  end

  def self.base_model
    PhysicalServerFirmwareUpdateTask
  end

  def do_request
    signal :run_firmware_update
  end

  def self.request_class
    PhysicalServerFirmwareUpdateRequest
  end

  def self.display_name(number = 1)
    n_('Firmware Update Task', 'Firmware Update Tasks', number)
  end
end
