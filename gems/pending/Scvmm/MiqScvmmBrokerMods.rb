require 'Scvmm/MiqScvmm'
require 'Scvmm/MiqScvmmInventory'

require 'drb'

class DMiqScvmm < MiqScvmm
  include DRb::DRbUndumped

  def initialize(server, username, password, broker, preLoad=false, debugUpdates=false)
    @broker = broker
    super(server, username, password)
    self.connect
  end
  
  def disconnect
    return true
  end
end

class MiqScvmmInventory
    include DRb::DRbUndumped
end
