$:.push("#{File.dirname(__FILE__)}/../libvirt")
$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}")
require 'miq-hash_struct'
require 'MiqLibvirt'
require 'MiqKvmVm'

class MiqKvmHost < MiqLibvirt::Host
  def initialize(server=nil, user=nil, pwd=nil)
    super(:kvm, 'qemu', server, user, pwd)
  end

  def getVm(uuid)
    ost = MiqHashStruct.new(:vmService => self)
    return MiqKvmVm.new(ost, {:uuid=>uuid})
  end
end
