require 'optparse'
require 'ostruct'
require 'rubygems'
require 'platform'

$:.push("#{File.dirname(__FILE__)}/implementations")
$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}/../util/diag")

if $log.nil?
  require 'log4r'
  $log = Log4r::Logger['toplog']
end

require 'VmwareOps'
require 'VmdbOps'
require 'MicrosoftOps'
require 'miqping'
require 'miq-password'
require 'miq-option-parser'

case Platform::OS
when :win32
    require 'HostWinOps'
when :unix
    require 'HostLinuxOps'
end

class MiqParser < MiqOptionParser::MiqCommandParser
	attr_accessor  :miqRet, :forceImpl

	def initialize(cfg=nil)
		super()
		self.handle_exceptions = true
		@miqRet = OpenStruct.new
		
		#
		# If we're being instantiated by miqhost, cfg will contain
		# the current miqhost configuration.
		#
		# We save the config OpenStruct as an element of the miqRet
		# OpenStruct so their name spaces will be separate.
		#
		if cfg
		    @miqRet.config = cfg
		else
		    #
		    # In local mode, miq-cmd can send data directly to the vmdb,
		    # so set the default vmdb host and port here.
		    #
		    @miqRet.config = OpenStruct.new
		    @miqRet.config.vmdbHost = "localhost"
		    @miqRet.config.vmdbPort = "3000"
		end
		
		@miqRet.config.ems = Hash.new if !@miqRet.config.ems
		
		#
		# Global defaults used by miq-cmd in remote mode.
		# Not used by miqhost.
		# 
		@miqRet.host = 'localhost'
		@miqRet.port = '1139'

		self.program_name = $0
		self.program_version = [0, 1, 0]
		
		currentEmsName = nil

		self.option_parser = OptionParser.new do |opt|
			opt.separator "Global options:"
			opt.on('-v', '--verbose', 'enable verbose output') do
				  @miqRet.verbose = true
			end
			#
			# For remote operation. The host and port of the miqhost agent
			# to which the request should be sent.
			#
			opt.on('-h=val', '--host=val', 'host for remote operations') do |h|
			    @miqRet.host = h
			    @miqRet.remote = true
			end
			opt.on('-p=val', '--port=val', 'port for remote operations') do |p|
			    @miqRet.port = p
			    @miqRet.remote = true
			end
			opt.on('-r', '--remote', 'perform operation on remote machine') do
			    @miqRet.remote = true
			end
			#
			# The host and port of the vmdb application.
			# This is where the retrieved information is sent.
			#
			opt.on('--vmdbhost=val', 'location of the vmdb server') do |h|
			    @miqRet.config.vmdbHost = h
			end
			opt.on('--vmdbport=val', 'vmdb server port') do |p|
			    @miqRet.config.vmdbPort = p
			end
			#
			# Information required to access an external management system or systems.
			#
			opt.on('--emsname=val', 'the name of the external management system') do |n|
			    @miqRet.config.ems[n] = Hash.new if !@miqRet.config.ems[n]
			    currentEmsName = n
			end
			opt.on('--emshost=val', 'location of the external management system') do |h|
			    raise "--emsname must preceed --emshost, --emsport, --emsuser and --emspassword" if !currentEmsName
			    @miqRet.config.ems[currentEmsName]['host'] = h
			end
			opt.on('--emsport=val', "the external management system's server port") do |p|
			    raise "--emsname must preceed --emshost, --emsport, --emsuser and --emspassword" if !currentEmsName
			    @miqRet.config.ems[currentEmsName]['port'] = p
			end
			opt.on('--emsuser=val', "the user name needed to access the external management system") do |u|
			    raise "--emsname must preceed --emshost, --emsport, --emsuser and --emspassword" if !currentEmsName
			    @miqRet.config.ems[currentEmsName]['user'] = u
			end
			opt.on('--emspassword=val', "the password needed to access the external management system") do |p|
			    raise "--emsname must preceed --emshost, --emsport, --emsuser and --emspassword" if !currentEmsName
			    @miqRet.config.ems[currentEmsName]['password'] = MiqPassword.encrypt(p)
			end
		end
		
		$log.debug "MiqParser: forceFleeceDefault = #{@miqRet.config.forceFleeceDefault}"
		
		self.add_command(GetVMProductInfo.new)
		self.add_command(StartVM.new)
		self.add_command(StopVM.new(@miqRet))
		self.add_command(CreateBlackBox.new)
		self.add_command(ReadBlackBox.new)
		self.add_command(WriteBlackBox.new)
		self.add_command(SyncMetadata.new(@miqRet))
		self.add_command(GetVMAttributes.new)
		self.add_command(GetVersion.new)
		self.add_command(GetVMs.new(@miqRet))
		self.add_command(GetVMState.new)
		self.add_command(GetHeartbeat.new)
		self.add_command(HasSnapshot.new)
		self.add_command(ResetVM.new)
		self.add_command(StartLogicalVM.new)
		self.add_command(SuspendVM.new)
    self.add_command(PauseVM.new)
		self.add_command(RegisterId.new(@miqRet))
		self.add_command(ScanMetadata.new(@miqRet))
		self.add_command(RegisterVM.new(@miqRet))
		self.add_command(SaveVmMetadata.new)
		self.add_command(SaveHostMetadata.new)
		self.add_command(HostHeartbeat.new)
		self.add_command(MakeSmart.new)
		self.add_command(GetHostConfig.new(@miqRet))
		self.add_command(GetVMConfig.new)
		self.add_command(SendVMState.new)
		self.add_command(StartLogicalService.new(@miqRet))
		self.add_command(ScanRepository.new(@miqRet))
		self.add_command(GetEmsInventory.new)
		self.add_command(SaveEmsInventory.new)
		self.add_command(MonitorEmsEvents.new)
		self.add_command(AgentRegister.new)
    self.add_command(AgentUnregister.new)
		self.add_command(AgentConfig.new)
		self.add_command(PolicyCheckVm.new)
		self.add_command(ServerPing.new(@miqRet))
		self.add_command(DeleteBlackBox.new(@miqRet))
		self.add_command(RecordBlackBoxEvent.new)
		self.add_command(ValidateBlackBox.new)
    self.add_command(CreateSnapshot.new(@miqRet))
    self.add_command(RemoveSnapshot.new)
    self.add_command(RemoveAllSnapshots.new)
    self.add_command(RevertToSnapshot.new)
    self.add_command(RemoveSnapshotByDescription.new)
    self.add_command(ShutdownGuest.new)
    self.add_command(StandbyGuest.new)
    self.add_command(RebootGuest.new)
    self.add_command(TaskUpdate.new)
    self.add_command(PowershellCommand.new(@miqRet))
    self.add_command(QueueAsyncResponse.new)
	end

	def clearRet
	    #
	    # Clear everything but the persistent configuration.
	    #
	    cfg = @miqRet.config
		@miqRet.marshal_load({})
		@miqRet.config = cfg
	end
end

class VerbBase < MiqOptionParser::MiqCommand
	def initialize(name, has_sub, switch_type, req_access=:write)
		super(name)		
		@switch = self.method(switch_type)
		@reqAccess = req_access
	end

	def execute(args)
		@parser = command_parser
		ret = @parser.miqRet
		ret.args = args
		ret.cmdObj = self
		
		begin
		    if ret.config
		        raise "Host is read only." if ret.config.readonly && @reqAccess != :read
		    end
		    if ret.remote
		        require 'WebSvcOps'
                @parser.forceImpl = WebSvcOps.new(ret)
			else
				# Call the policy_check method if it is defined - It will raise an error if policy fails
				self.policy_check(ret) if self.respond_to?(:policy_check)
			end
			
		    if @parser.forceImpl
		        op = @parser.forceImpl
		    else
		        op = @switch.call(ret).new(ret)
		    end
		    if self.class.to_s == "ScanMetadata"
		        $log.debug "execute: ret.force = #{ret.force}"
		        $log.debug "execute: @parser.miqRet.config.forceFleeceDefault = #{@parser.miqRet.config.forceFleeceDefault}"
		    end
		    op.send(self.class.to_s, ret)
		rescue => err
		    ret.error = err.to_s + "\n" + err.backtrace.join("\n")
		end
	end

	def vmSwitch(ost)
		begin
			ext = File.extname(ost.args[0])
		rescue => err
			ext = ""
		end

    # Only load the MicrosoftOps with we are running on a MS platform
    # This allows repository fleece of MS VMs. FB 1736
		return MicrosoftOps if Platform::OS == :win32 && ['.vmc', '.xml'].include?(ext)
		VMWareOps
	end

	def hostSwitch(ost)
    case Platform::OS
    when :win32
      MiqWin::HostConfigData
    when :unix
      MiqLinux::HostLinuxOps
    else
      VMWareOps
    end
	end
	
	def vmdbSwitch(ost)
	    VmdbOps
	end
	
	def emsSwitch(ost)
    ems = self.hostSwitch(ost).new(ost).ems rescue nil
    return ems unless ems.nil?    

    require 'VMWareWebSvcOps'
    VMWareWebSvcOps
	end
end

class GetVMProductInfo < VerbBase
	def initialize
		super('getvmproductinfo', false, :vmSwitch, :read)
		self.short_desc = "Get the product information for the given virtual machine"
	end
end

class StartVM < VerbBase
	def initialize
		super('startvm', false, :vmSwitch, :write)
		self.short_desc = "Start virtual machine by name"
	end
 
  def policy_check(ost)
	  VmdbOps.new(ost).policyCheckVmInternal(ost)
  end
end

class StopVM < VerbBase
	def initialize(ostruct)
		super('stopvm', false, :vmSwitch, :write)
		self.short_desc = "Stop virtual machine by name"
		self.option_parser = OptionParser.new do |opt|
			opt.separator "stopvm options:"
			opt.on('-t=val', '--type=val') do |v|
				ostruct.type = v
			end
			opt.on('-h', '--help', 'Display this help message') do
				show_help
				exit
			end
		end
	end
end

class CreateBlackBox < VerbBase
 	def initialize
 		super('createblackbox', false, :vmSwitch, :write)
 		self.short_desc = "Create black box for given virtual machine"
 	end
end

class ValidateBlackBox < VerbBase
 	def initialize
 		super('validateblackbox', false, :vmSwitch, :read)
 		self.short_desc = "Validate black box for given virtual machine"
 	end
end

class ReadBlackBox < VerbBase
	def initialize
		super('readblackbox', false, :vmSwitch, :read)
		self.short_desc = "Read the contents of a virtual machines black box"
	end
end

class WriteBlackBox < VerbBase
	def initialize
		super('writeblackbox', false, :vmSwitch, :write)
		self.short_desc = "Write the contents of a virtual machine's black box"
	end
end

class SyncMetadata < VerbBase
	def initialize(ostruct)
		super('syncmetadata', false, :vmSwitch, :read)
		self.short_desc = "Synchronize the metadata of the given virtual machine"
		self.option_parser = OptionParser.new do |opt|
			opt.separator "syncmetadata options:"
			opt.on('-c=val', '--category=val') do |v|
				ostruct.category = v
			end
			opt.on('-f=val', '--from_time=val') do |v|
				ostruct.from_time = v
				ostruct.from_time = ostruct.from_time.gsub!("\"","") if ostruct.from_time.include?("\"")
			end
			opt.on('-t=val', '--taskid=val') do |v|				
				ostruct.taskid = v
				ostruct.taskid = ostruct.taskid.gsub!("\"","") if ostruct.taskid.include?("\"")
			end
			opt.on('-h', '--help', 'Display this help message') do
				show_help
				exit
			end
		end    
	end
end

class GetVMAttributes < VerbBase
	def initialize
		super('getvmattributes', false, :vmSwitch, :read)
		self.short_desc = "Get the attributes of the given virtual machine"
	end
end

class GetVersion < VerbBase
	def initialize
		super('getversion', false, :hostSwitch, :read)
		self.short_desc = "Get the version host machine"
	end
end

class GetVMs < VerbBase
	def initialize(ostruct)
		super('getvms', false, :hostSwitch, :read)
		self.short_desc = "List the virtual machines on this host"
		self.option_parser = OptionParser.new do |opt|
			opt.separator "getvms options:"
			opt.on('-f', '--format') do |v|
				ostruct.fmt = true
			end
			opt.on('-h', '--help', 'Display this help message') do
				show_help
				exit
			end
		end
	end
end

class ScanRepository < VerbBase
	def initialize(ostruct)
		super('scanrepository', false, :vmSwitch, :read)
		self.short_desc = "List the virtual machines at a specified location"
		self.option_parser = OptionParser.new do |opt|
			opt.separator "scanrepository options:"
			opt.on('-f', '--format') do |v|
				ostruct.fmt = true
			end
			opt.on('-h', '--help', 'Display this help message') do
				show_help
				exit
			end
		end
	end
end

class GetVMState < VerbBase
	def initialize
		super('getvmstate', false, :vmSwitch, :read)
		self.short_desc = "Get the state of the given virtual machine"
	end
end

class GetHeartbeat < VerbBase
	def initialize
		super('getheartbeat', false, :vmSwitch, :read)
		self.short_desc = "Get the heartbeat of the given virtual machine"
	end
end

class HasSnapshot < VerbBase
	def initialize
		super('hassnapshot', false, :vmSwitch, :read)
		self.short_desc = "Determine if a snapshot has been taken of the given virtual machine"
	end
end

class ResetVM < VerbBase
	def initialize
		super('resetvm', false, :vmSwitch, :write)
		self.short_desc = "Reset the given virtual machine"
	end
end

class StartLogicalVM < VerbBase
	def initialize
		super('startlogicalvm', false, :vmSwitch, :write)
		self.short_desc = "Start a virtual machine identified by its attributes"
	end
end

class SuspendVM < VerbBase
	def initialize
		super('suspendvm', false, :vmSwitch, :write)
		self.short_desc = "Suspend the given virtual machine"
	end
end

class PauseVM < VerbBase
	def initialize
		super('pausevm', false, :vmSwitch, :write)
		self.short_desc = "Pause the given virtual machine"
	end
end

class RegisterId < VerbBase
	def initialize(ostruct)
		super('registerid', false, :vmSwitch, :read)
		self.short_desc = "Associate a unique ID with the given virtual machine"
		self.option_parser = OptionParser.new do |opt|
			opt.separator "registerid options:"
			opt.on('-i=val', '--id=val') do |v|
				ostruct.vmId = v
			end
			opt.on('-h', '--help', 'Display this help message') do
				show_help
				exit
			end
		end
	end
end

class RegisterVM < VerbBase
	def initialize(ostruct)
		super('registervm', false, :vmSwitch, :read)
		self.short_desc = "Register the given virtual machine"
		self.option_parser = OptionParser.new do |opt|
			opt.separator "registervm options:"
			opt.on('-h', '--help', 'Display this help message') do
				show_help
				exit
			end
		end
	end
end

class ScanMetadata < VerbBase
	def initialize(ostruct)
		super('scanmetadata', false, :vmSwitch, :read)
		self.short_desc = "Scan and save the given VM's metadata"
		self.option_parser = OptionParser.new do |opt|
			opt.separator "scanmetadata options:"
			opt.on('-c=val', '--category=val') do |v|
				ostruct.category = v
			end
			opt.on('-f', '--force', "Force scan, even if locked") do		
				ostruct.force = true
				$log.debug "ScanMetadata: force changed to: #{ostruct.force}"
			end
			opt.on('-n', '--noforce', "Do not force scan") do			
				ostruct.force = false
				$log.debug "ScanMetadata: force changed to: #{ostruct.force}"
			end
			opt.on('-t=val', '--taskid=val') do |v|				
				ostruct.taskid = v
				ostruct.taskid = ostruct.taskid.gsub!("\"","") if ostruct.taskid.include?("\"")
			end
			opt.on('-h', '--help', 'Display this help message') do
				show_help
				exit
			end
		end    		
	end
end

class GetVMConfig < VerbBase
	def initialize
		super('getvmconfig', false, :vmSwitch, :read)
		self.short_desc = "Transfer VM config file to the server"
	end
end

class SaveVmMetadata < VerbBase
	def initialize
		super('savevmmetadata', false, :vmSwitch, :read)
		self.short_desc = "Save the given VM's metadata"
	end
end

class SaveHostMetadata < VerbBase
	def initialize
		super('savehostmetadata', false, :vmSwitch, :read)
		self.short_desc = "Save the given Host's metadata"
	end
end

class SaveEmsInventory < VerbBase
	def initialize
		super('saveemsinventory', false, :vmdbSwitch, :read) # XXX why :vmSwitch?
		self.short_desc = "Save the inventory acquired from a given external management system"
	end
end

class HostHeartbeat < VerbBase
	def initialize
		super('hostheartbeat', false, :vmSwitch, :read)
		self.short_desc = "Send heartbeat to db"
	end
end

class MakeSmart < VerbBase
	def initialize
		super('makesmart', false, :vmSwitch, :write)
		self.short_desc = "Make the given VM an MIQ Smart VM"
	end
end

class GetHostConfig < VerbBase
	def initialize(ostruct)
		super('gethostconfig', false, :hostSwitch, :read)
		self.short_desc = "Get Host OS and hardware information"
	end
end

class SendVMState < VerbBase
	def initialize
		super('sendvmstate', false, :vmSwitch, :read)
		self.short_desc = "Send the state of the given virtual machine to the server"
	end
end

class StartLogicalService < VerbBase
	def initialize(ostruct)
		super('startservice', false, :vmdbSwitch, :write)
		self.short_desc = "Start the underlying virtual machines for a given logical service"
		self.option_parser = OptionParser.new do |opt|
			opt.separator "startservice options:"
			opt.on('-u=val', '--userid=val', "The user starting the service") do |v|
				ostruct.userid = v
			end
			opt.on('-s=val', '--service=val', "The name of the service") do |v|
				ostruct.service = v
			end
			opt.on('-w=val', '--when=val', "When the service should start") do |v|
				ostruct.when = v
			end
			opt.on('-h', '--help', 'Display this help message') do
				show_help
				exit
			end
		end    
	end
end

class GetEmsInventory < VerbBase
    def initialize
        super("getemsinventory", false, :emsSwitch, :read)
        self.short_desc = "Retrieve inventory from named external management system"
    end
end

class MonitorEmsEvents < VerbBase
    def initialize
        super("monitoremsevents", false, :emsSwitch, :read)
        self.short_desc = "Monitor events from named external management system"
    end
end

class AgentRegister < VerbBase
    def initialize
        super("agentregister", false, :vmdbSwitch, :read)
        self.short_desc = "Register agent with server"
    end
end

class AgentUnregister < VerbBase
    def initialize
        super("agentunregister", false, :vmdbSwitch, :read)
        self.short_desc = "Unregister agent from server"
    end
end

class AgentConfig < VerbBase
    def initialize
        super("agentconfig", false, :vmdbSwitch, :read)
        self.short_desc = "Send agent configuration settings to the server"
    end
end

class PolicyCheckVm < VerbBase
	def initialize
		super('policycheckvm', false, :vmdbSwitch, :read)
		self.short_desc = "Return the policy evaluation for the given VM"
	end
end

class ServerPing < VerbBase
	def initialize(ostruct)
		super('serverping', false, :vmdbSwitch, :read)
		self.short_desc = "Send test data to server"

		ostruct.pingCfg = OpenStruct.new(Manageiq::MiqWsPing.defaults)
		ostruct.pingCfg.host = ostruct.config.vmdbHost
		ostruct.pingCfg.port = ostruct.config.vmdbPort
		self.option_parser = OptionParser.new do |opt|
			opt.on('--host=<host>', 'remote host name or ip address', String) {|val| ostruct.pingCfg.host = val}
			opt.on('--port=<port>', 'remote listening port number', Integer) {|val| ostruct.pingCfg.port = val}
			opt.on('--total=<number>', 'numner of ping transactions to execute', Integer) {|val| ostruct.pingCfg.total = val}
			opt.on('--bytes=<number>', 'number of bytes to send to remote node', Integer) {|val| ostruct.pingCfg.bytes = val}
			opt.on('--debug=[0|1]', 'enable/disable wire trace', Integer) {|val| ostruct.pingCfg.debug = val}
			opt.on('--mode=[agent|server]', 'ping agent or server', String) {|val| ostruct.pingCfg.mode = val}
		end
	end
end

class DeleteBlackBox < VerbBase
	def initialize(ostruct)
		super('deleteblackbox', false, :vmSwitch, :write)
		self.short_desc = "Delete the black box of the given virtual machine"
	end
end

class RecordBlackBoxEvent < VerbBase
	def initialize
		super('recordblackboxevent', false, :vmSwitch, :write)
		self.short_desc = "Record an event to the black box of the given virtual machine"
	end
end

class CreateSnapshot < VerbBase
	def initialize(ostruct)
		super('createsnapshot', false, :vmSwitch, :write)
		self.short_desc = "Create a VM snapshot"
		self.option_parser = OptionParser.new do |opt|
			opt.separator "Create Snapshot options:"
			opt.on('-n=val', '--name=val') do |v|
				ostruct.name = v
        ostruct.name = ostruct.name[1..-2] if ostruct.name[0,1] == '"' && ostruct.name[-1,1] == '"'
			end
			opt.on('-d=val', '--description=val') do |v|
				ostruct.description = v
        ostruct.description = ostruct.description[1..-2] if ostruct.description[0,1] == '"' && ostruct.description[-1,1] == '"'
			end
			opt.on('-m', '--memory', "Snapshot VM Memory") {ostruct.memory = true}
      opt.on('-q', '--quiesce', "Quiesce VM") {ostruct.quiesce = true}
			opt.on('-h', '--help', 'Display this help message') do
				show_help
				exit
			end
		end
	end
end

class RemoveSnapshot < VerbBase
	def initialize
		super('removesnapshot', false, :vmSwitch, :write)
		self.short_desc = "Remove a snapshot from the given virtual machine"
	end
end

class RemoveAllSnapshots < VerbBase
	def initialize
		super('removeallsnapshots', false, :vmSwitch, :write)
		self.short_desc = "Remove all snapshots from the given virtual machine"
	end
end

class RevertToSnapshot < VerbBase
	def initialize
		super('reverttosnapshot', false, :vmSwitch, :write)
		self.short_desc = "Revert to a previous snapshot from the given virtual machine"
	end
end

class RemoveSnapshotByDescription < VerbBase
	def initialize
		super('removesnapshotbydescription', false, :vmSwitch, :write)
		self.short_desc = "Remove a snapshot from the given virtual machine based on the snapshot description"
	end
end

class ShutdownGuest < VerbBase
	def initialize
		super('shutdownguest', false, :vmSwitch, :write)
		self.short_desc = "Shutdown the given virtual machine"
	end
end

class StandbyGuest < VerbBase
	def initialize
		super('standbyguest', false, :vmSwitch, :write)
		self.short_desc = "Put the given virtual machine in a Standby state"
	end
end

class RebootGuest < VerbBase
	def initialize
		super('rebootguest', false, :vmSwitch, :write)
		self.short_desc = "Reboot the given virtual machine"
	end
end

class TaskUpdate < VerbBase
	def initialize
		super('taskupdate', false, :vmSwitch, :read)
		self.short_desc = "Update Task state, status and message"
	end
end

class PowershellCommand < VerbBase
	def initialize(ostruct)
		super('powershellcommand', false, :hostSwitch, :read)
		self.short_desc = "Execute Powershell script"
	end
end

class QueueAsyncResponse < VerbBase
  def initialize
    super("queueasyncresponse", false, :vmdbSwitch, :read)
    self.short_desc = "Transfer data to the server for processing"
  end
end
