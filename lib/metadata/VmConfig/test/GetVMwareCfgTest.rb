# Only run if we are calling this script directly
$:.push("#{File.dirname(__FILE__)}/../../../util")
$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../../MiqExtract")
require 'miq-logger'
require 'VmConfig'
require 'MiqExtract'
$log = MIQLogger.get_log(nil, __FILE__)
$log.level = Log4r::DEBUG

vmNames = []
#	vmNames << "//miq-websvr1/scratch2/vmimages/VMware/DHCP Server/Windows Server 2003 Standard Edition.vmx"
#	vmNames << "//miq-websvr1/scratch2/vmimages/VMware/SQL 2005 1/SQL1.vmx"
#	vmNames << "//miq-websvr1/scratch2/vmimages/VMware/Domain Controller/Windows Server 2003 Standard Edition.vmx"
#	vmNames << "//miq-websvr1/scratch2/vmimages/VMware/SQL 2005 2/SQL1.vmx"
#	vmNames << "//miq-websvr1/scratch2/vmimages/VMware/VMWare Appliance Marketplace/operating systems/Ubuntu-baseline/Ubuntu server 7.04 EXT2/Ubuntu.vmx"
#	vmNames << "//miq-websvr1/scratch2/vmimages/VMware/VMWare Appliance Marketplace/rmoore/Squid/squidserver-minimal.tar/squidserver-minimal/squidserver-minimal/squidserver-minimal.vmx"
#	vmNames << "//miq-websvr1/scratch2/vmimages/VMware/Win2K3-EE Fat32/Windows Server 2003 Enterprise Edition.vmx"
#	vmNames << "//miq-websvr1/scratch2/vmimages/VirtualPC/WS03R2EE_EXCH_LCS/WS03R2EE_EXCH_LCS.vmc"
#vmNames << "C:/Virtual Machines/MiqSprint25/MIQ Server Appliance - Ubuntu.vmx"
#vmNames << "C:/Virtual Machines/Clone of SQL Svr 1/Clone of SQL Svr 1.vmx"
vmNames << "C:/Virtual Machines/10425-2008-10-05.023502/Ubuntu.vmx"


vmNames.each do |vmName|
  begin
    vmCfg = VmConfig.new(vmName)

    # Print all key/value pairs
    #vmCfg.getHash.each_pair { |k, v| puts "#{k} => #{v}" }

    # Get xml object and print to screen in a nice format
    miqvm = MiqVm.new(vmName, nil)

    xml = vmCfg.toXML(true, miqvm)
    xml.write(STDOUT, 0)
    puts "\n"
  rescue => err
    $log.error err
    $log.error err.backtrace.join("\n")
  end
end

$log.info "done"
