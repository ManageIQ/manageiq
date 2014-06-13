$:.push("#{File.dirname(__FILE__)}")
require 'MiqKvmHost'

class MiqKvmInventory
  def initialize(server, username, password)
    @server, @username, @password = server, username, password
  end

  def connect
    # NOP
  end

  def disconnect
    # NOP
  end

  def refresh()
    return MiqKvmHost.new(@server, @username, @password).to_inv_h
  end
end
