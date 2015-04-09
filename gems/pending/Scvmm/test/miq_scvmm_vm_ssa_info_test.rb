$LOAD_PATH.push("#{File.dirname(__FILE__)}/..")

require 'rubygems'
require 'log4r'
require 'miq_scvmm_vm_ssa_info'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
  def format(event)
    (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
  end
end

$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level => Log4r::DEBUG, :formatter => ConsoleFormatter)
$log.add 'err_console'

HOST = raise "Please define SERVERNAME"
PORT = raise "Please define PORT"
USER = raise "Please define USER"
PASS = raise "Please define PASS"
VM   = raise "Please define VM"

vm_info_handle = MiqScvmmVmSSAInfo.new(HOST, USER, PASS, PORT)
$log.debug "Getting Hyper-V Host for VM #{VM}"
hyperv_host    = vm_info_handle.vm_host(VM)
$log.debug "Hyper-V Host is #{hyperv_host}"
$log.debug "Getting VHD Type for VM #{VM}"
vhd_type       = vm_info_handle.vm_vhdtype(VM)
$log.debug "VHD Type is #{vhd_type}"
vhd            = vm_info_handle.vm_harddisks(VM)
$log.debug "VHD is #{vhd}"
