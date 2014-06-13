$:.push("#{File.dirname(__FILE__)}/../../metadata/util/win32")
$:.push("#{File.dirname(__FILE__)}/../../metadata/VmConfig")
$:.push("#{File.dirname(__FILE__)}/../../util")

require 'win32ole'
require 'ostruct'
require 'win32/registry'
require "win32/service"
require 'versioninfo'
require 'VmConfig'
require 'miq-extensions'

class VmwareCom
	# Constants
	#=====================================
	# VmExecutionState
	#=====================================
	VMEXECUTIONSTATE_OFF = 2
	VMEXECUTIONSTATE_ON = 1
	VMEXECUTIONSTATE_STUCK = 4
	VMEXECUTIONSTATE_SUSPENDED = 3
	VMEXECUTIONSTATE_UNKNOWN = 5
	
	#=====================================
	# VmPowerOpMode
	#=====================================
	VMPOWEROPMODE_HARD = 1
	VMPOWEROPMODE_SOFT = 2
	VMPOWEROPMODE_TRYSOFT = 3
	
	#=====================================
	# VmErr
	#=====================================
	VMERR_ALREADYCONNECTED = -2147220980
	VMERR_BADRESPONSE = -2147220978
	VMERR_BADSTATE = -2147220984
	VMERR_BADVERSION = -2147220986
	VMERR_DISCONNECT = -2147220979
	VMERR_GARBAGE = -2147220977
	VMERR_INSUFFICIENT_RESOURCES = -2147220970
	VMERR_INVALIDARGS = -2147220989
	VMERR_INVALIDVM = -2147220974
	VMERR_NEEDINPUT = -2147220976
	VMERR_NETFAIL = -2147220990
	VMERR_NOACCESS = -2147220988
	VMERR_NOEXECVMAUTHD = -2147220983
	VMERR_NOMEM = -2147220991
	VMERR_NOPROPERTY = -2147220982
	VMERR_NOSUCHVM = -2147220981
	VMERR_NOTCONNECTED = -2147220987
	VMERR_NOTSUPPORTED = -2147220975
	VMERR_PROXYFAIL = -2147220969
	VMERR_TIMEOUT = -2147220985
	VMERR_UNSPECIFIED = -2147219993
	VMERR_VMBUSY = -2147220971
	VMERR_VMEXISTS = -2147220972
	VMERR_VMINITFAILED = -2147220973
	#'=====================================
	#' VmPlatform
	#'=====================================
	VMPLATFORM_LINUX = 2
	VMPLATFORM_UNKNOWN = 4
	VMPLATFORM_VMNIX = 3
	VMPLATFORM_WINDOWS = 1
	#'=====================================
	#' VmProdInfoType
	#'=====================================
	VMPRODINFO_BUILD = 3
	VMPRODINFO_PLATFORM = 2
	VMPRODINFO_PRODUCT = 1
	VMPRODINFO_VERSION_MAJOR = 4
	VMPRODINFO_VERSION_MINOR = 5
	VMPRODINFO_VERSION_REVISION = 6
	#=====================================
	# VmProduct
	#=====================================
	VMPRODUCT_ESX = 3
	VMPRODUCT_GSX = 2
	VMPRODUCT_UNKNOWN = 4
	VMPRODUCT_WS = 1
	#=====================================
	# VmTimeoutId
	#=====================================
	VMTIMEOUTID_DEFAULT = 1
	
	def initialize(ost=nil)
      hyper = hypervisorVersion()
      raise "VMware hypervisor not configured." if hyper.empty?

      if @product_type == :Server
        WIN32OLE.ole_initialize
        @cp = WIN32OLE.new("VmCOM.VmConnectParams")
        @server = WIN32OLE.new("VmCOM.VmServerCtl")
        @server.Connect @cp
      else
        @server = VmwareWinWorkStationServer.new()
      end
  end
		
	def registeredVms
    @server.RegisteredVmNames.inject([]) {|vms, vmName| vms << vmName; vms}
    end
	
	def state(vmName)
    return State2Str(connectVm(vmName))
	end
	
	def start(vmName, mode=VMPOWEROPMODE_SOFT)
		connectVm(vmName).Start(mode)
		return true
	end
	
	def stop(vmName, mode=VMPOWEROPMODE_TRYSOFT)
		connectVm(vmName).Stop(mode)
		return true
	end
	
	def suspend(vmName, mode=VMPOWEROPMODE_TRYSOFT)
		connectVm(vmName).Suspend(mode)
		return true
	end
	
	def reset(vmName, mode=VMPOWEROPMODE_TRYSOFT)
		connectVm(vmName).Reset(mode)
		return true
	end
	
	def heartbeat(vmName)
		connectVm(vmName).Heartbeat()
	end
	
	def timeout(vmName)
		connectVm(vmName).Timeout()
	end
	
	def connectVm(vmName)
    if @product_type == :Server
      WIN32OLE.ole_initialize
      vm = WIN32OLE.new("VmCOM.VmCtl")
      vm.connect(@cp, normalizeVmName(vmName))
    else
      vm = VmwareWinWorkStationVm.new(normalizeVmName(vmName))
    end
		return vm
	end
	
	def normalizeVmName(vmName)
		vmName.gsub("/", "\\")
	end
	
	def State2Str(vm)
		case (vm.ExecutionState)
		when VMEXECUTIONSTATE_ON
			return "on"
		when VMEXECUTIONSTATE_OFF
			return "off"
		when VMEXECUTIONSTATE_SUSPENDED
			return "suspended"
		when VMEXECUTIONSTATE_STUCK
			return "stuck"
		else
			return "unknown"
		end
	end

  def hypervisorVersion()
    begin
      installPath = Win32::Service.config_info("VMAuthdService").binary_path_name rescue ""
      return {} if installPath.empty?

      installPath = installPath[1..-2] if installPath[0,1] == '"' and installPath[-1,1] == '"'
      installPath = installPath.gsub('\\','/')
      vi = File.getVersionInfo(File.join(File.dirname(installPath), "vmware.exe"))
      va = vi['ProductName'] + " " + vi['FileVersion']
      va = va.split(" ")
      verHash = {"vendor"=>"vmware", "product"=>va[1..-3].join(" "), "version"=>va[-2], "build"=>va[-1].delete("build-")}
      @product_type = verHash["product"].to_sym
      return verHash
    rescue
      {}
    end
  end

  def MonitorEmsEvents(ost)
    # EMS monitoring not supported for this system
    return nil
	end
end

class VmwareWinWorkStationServer
  def RegisteredVmNames()
    vmware_data_path = "VMware"

    vm_list = {}
    self.get_user_app_data_paths().each do |d|
      if File.directory?(d)
        f = File.join(d, vmware_data_path, "favorites.vmls")
        VmConfig.to_h(f).each {|k,v| vm_list[v[:config].downcase] ||= v} if File.exist?(f)
      end
    end

    # Make sure we do not return any VMs that do not exist anymore
    vm_list.delete_if {|key, value| !File.exist?(value[:config])}

    vm_list.collect {|k, v| v[:config]}
  end

  def get_user_app_data_paths
    paths = []
    Win32::Registry::HKEY_USERS.open('') do |reg|
      reg.each_key do |key, wtime|
        next if key == '.DEFAULT' || key.length < 10
        shellFolders = "#{key}\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Shell Folders"
        Win32::Registry::HKEY_USERS.open(shellFolders) {|reg2| paths << reg2['AppData'] if reg2['AppData'] && File.exist?(reg2['AppData'])} rescue nil
      end
    end
    return paths
  end
end


class VmwareWinWorkStationVm
  def initialize(vmName)
    @vmName = vmName
  end

	def ExecutionState()
    return VmwareCom::VMEXECUTIONSTATE_UNKNOWN unless File.exist?(@vmName)
    state = VmwareCom::VMEXECUTIONSTATE_OFF
    state = VmwareCom::VMEXECUTIONSTATE_SUSPENDED if File.exist?(File.join(File.dirname(@vmName), File.basename(@vmName, ".vmx") + ".vmss"))
    WMIHelper.connectServer().run_query("select * from Win32_Process where Name = 'vmware-vmx.exe'") do |p|
      state = VmwareCom::VMEXECUTIONSTATE_ON if p.CommandLine.downcase.include?(@vmName.downcase)
    end
    return state
  end
end

if __FILE__ == $0 then
  vmc = VmwareCom.new rescue nil
  if vmc
    p vmc.hypervisorVersion
    x = vmc.registeredVms
    p x.length
    p x
    #	p vmc.start("C:/Virtual Machines/Dan-XP-VM/Windows XP Professional.vmx")
    #	sleep(10)
    #	p vmc.heartbeat("C:/Virtual Machines/Dan-XP-VM/Windows XP Professional.vmx")
    #	p vmc.reset("C:/Virtual Machines/Dan-XP-VM/Windows XP Professional.vmx")
    #	p vmc.stop("C:/Virtual Machines/Dan-XP-VM/Windows XP Professional.vmx")
  end

  p "done"
end
