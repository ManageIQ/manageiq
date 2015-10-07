require 'Scvmm/MiqScvmm'
require 'Scvmm/MiqScvmmInventory'

require 'drb'

class DMiqScvmm < MiqScvmm
  include DRb::DRbUndumped

  def initialize(server, username, password, broker, _preLoad = false, _debugUpdates = false)
    @broker = broker
    super(server, username, password)
    connect
  end

  def disconnect
    true
  end
end

class MiqScvmmInventory
  include DRb::DRbUndumped
end
