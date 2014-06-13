$:.push("#{File.dirname(__FILE__)}")
require 'MiqHypervInventory'
require 'MiqHypervInventoryParser'
require 'MiqHypervVm'
require 'sync'

class MiqHyperV < MiqHypervInventory
  attr_reader :connected
  attr_accessor :stdout

  def initialize(server=nil, username=nil, password=nil)
    super
    @connected = false
    @cacheLock  = Sync.new
  end

  def getVm(path)
    self.get_vm_by_uuid(File.basename(path, '.*'))
  end

  def get_vm_by_uuid(uuid)
    miqVm = nil
    @cacheLock.synchronize(:SH) do
      raise "VM with ID [#{uuid.downcase}] not found" if !(vmh = virtualMachines[uuid.downcase])
      miqVm = MiqHypervVm.new(self, conditionalCopy(vmh))
    end
    return(miqVm)
  end

	def get_host(name=nil)
		miqHost = nil
    @cacheLock.synchronize(:SH) do
      raise "Could not find Host: #{name}" if !(hh = hostSystems_locked[name])
			miqHost = MiqHypervHost.new(self, conditionalCopy(hh))
    end
		$log.info "MiqHyperV.get_host returning object #{miqHost.object_id}"
    return(miqHost)
	end

	def get_host_by_uuid(hMor)
		miqHypervHost = nil
    @cacheLock.synchronize(:SH) do
      raise "Could not find Host: #{hMor}" if !(hh = hostSystemsByMor_locked[hMor])
			miqHypervHost = MiqHypervHost.new(self, conditionalCopy(hh))
    end
		$log.info "MiqHyperV.get_host_by_uuid: returning object #{miqHypervHost.object_id}"
		return(miqHypervHost)
	end

end # class MiqScvmm
