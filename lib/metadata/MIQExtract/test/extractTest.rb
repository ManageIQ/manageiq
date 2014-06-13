
$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../../../MiqVm")

require 'MIQExtract'
require 'rubygems'
require 'log4r'
require 'MiqVm'
    
# vmDir = "v:"
vmDir = File.join(ENV.fetch("HOME", '.'), 'VMs')
puts "vmDir = #{vmDir}"

class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end

toplog = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::ERROR, :formatter=>ConsoleFormatter)
toplog.add 'err_console'
$log = toplog if $log.nil?

#
# *** Test start
#

# vmCfgFile = File.join(vmDir, "UbuntuDev.vmwarevm/UbuntuDev.vmx")
# vmCfgFile = File.join(vmDir, "gentoo/gentoo.vmx")
# vmCfgFile = File.join(vmDir, "Ken_Linux/Ken_Linux.vmx")
# vmCfgFile = File.join(vmDir, "Metasploit VM/Metasploit VM.vmx")
# vmCfgFile = File.join(vmDir, "KnopDev.vmwarevm/KnopDev.vmx")
vmCfgFile = File.join(vmDir, "Red Hat Linux.vmwarevm/Red Hat Linux.vmx")
# vmCfgFile = File.join(vmDir, "MIQ Server Appliance - Ubuntu MD - small/MIQ Server Appliance - Ubuntu.vmx")
# vmCfgFile = File.join(vmDir, "winxpDev.vmwarevm/winxpDev.vmx")
puts "VM config file: #{vmCfgFile}"

ost = OpenStruct.new
vmCfg = MIQExtract.new(vmCfgFile, ost)
xml = vmCfg.extract(["software"])

xml.write($stdout, 4)
puts

vmCfg.close()