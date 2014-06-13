$:.push("#{File.dirname(__FILE__)}/../libvirt")
require 'MiqLibvirtVm'

class MiqKvmVm < MiqLibvirt::Vm
  def initialize(*args)
    super
  end
end
