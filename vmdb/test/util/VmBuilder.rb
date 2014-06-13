require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))
$:.push("C:/dev/miq/lib/blackbox")
require 'VmBlackBox'
gem 'activerecord'


sqlip = "192.168.126.129"
hostip = "192.168.126.1"
hostid = "15"

vmxFile = []
#vmxFiles = ["C:/Users/jrafaniello/Documents/My Virtual Machines/Web Server/Windows Server 2003 Standard Edition.vmx"]

 vmxFiles = ["C:/Users/jrafaniello/Documents/My Virtual Machines/Windows Server 2003 Enterprise x64 Edition/Windows Server 2003 Enterprise x64 Edition.vmx",
            "C:/Users/jrafaniello/Documents/My Virtual Machines/WinXP Testcase/Windows XP Professional.vmx",
            "C:/Users/jrafaniello/Documents/My Virtual Machines/Windows 2000 Professional/Windows 2000 Professional.vmx"]

names1 = ["Production", "Test", "Development"]
names2 = ["Domain Controller", "Proxy Server", "Webserver", "Workstation"]

### open the Db connection
ActiveRecord::Base.establish_connection(
  :adapter    =>  "mysql",
  :host       =>  sqlip,
  :database   =>  "vmdb_development",
  :username   =>  "root"
)
class Jobs < ActiveRecord::Base
end

class Vms < ActiveRecord::Base
end

class Hosts < ActiveRecord::Base
end


def delete_blackbox(vmxPath)
  bb = File.dirname(vmxPath)<<"/"<<File.basename(vmxPath,".*")<<"-MiqBB.vmdk"
  bbf = File.dirname(vmxPath)<<"/"<<File.basename(vmxPath,".*")<<"-MiqBB-flat.vmdk"
  begin
    File.delete(bbf) if File.exists?(bbf)
  rescue
    puts "#{Time.now} !!! Unable to delete #{bbf}"
    return 1
  end
  begin
    File.delete(bb) if File.exists?(bb)
  rescue
    puts "#{Time.now} !!! Unable to delete #{bb}"
    return 1
  end
  return 0
end


def host_busy?
   Jobs.count(:conditions => "state != 'finished' and message != 'Processing VM data'")
end

thisHost = Hosts.find(:first, :conditions => hostid)
thisHost.ipaddress = hostip
thisHost.save

lastVmTime = 0
100.times do |i|
  vmxFiles.each do | vmFileToFleece |
    print "#{Time.now} Waiting for #{host_busy?} job(s)" if host_busy? > 0
    count = 0
    while host_busy? > 0
      count = count + 1
      if (count > 20)
        print "\n #{Time.now} Bailing on #{vmFileToFleece}\n"
        break
      end
      sleep 30
      print "."
    end
    print "\n"

    puts "#{Time.now} Last Vm took #{(lastVmTime - Time.now).abs} sec. Now #{Vms.count} Vms" unless lastVmTime == 0
    lastVmTime = Time.now


    puts "#{Time.now} Start #{File.basename(vmFileToFleece)}"

  #  puts vmxFiles
  #  puts vmxFiles.length
  #  puts rand(vmxFiles.length - 1)

  #  puts vmFileToFleece

    ### delete the blackbox
    break if delete_blackbox(vmFileToFleece) != 0

    #puts "#{Time.now} Connecting to DB and copying"

    ### find the row to copy
    vmToCopy = Vms.find(:first, :order => "id DESC")

  #  puts "vmToCopy = #{vmToCopy}"

    newName = names1[rand(3)] + " " + names2[rand(4)]
  #  puts "newName = #{newName}"

    ### create a copy of the row
    newVm = Vms.create(
      :vendor       => vmToCopy[:vendor],
      :format       => vmToCopy[:format],
      :version      => vmToCopy[:version],
      :name         => newName,
      :description  => vmToCopy[:description],
      :location     => "file:///" + vmFileToFleece,
      :config_xml   => vmToCopy[:config_xml],
      :busy         => vmToCopy[:busy],
      :registered   => 0,
      :autostart    => vmToCopy[:autostart],
      :host_id      => hostid,
      :smart        => vmToCopy[:smart],
      :last_extract_time => vmToCopy[:last_extract_time],
      :storage_id   => vmToCopy[:storage_id]
    )

    newVm.guid = newVm.id
    newVm.save!
  #  puts newVm.inspect


    # find the Vm from the vm table
    myVm = Vm.find newVm[:id]

  #  puts myVm.inspect
      # Call web services for the vm's host with the request to register
    puts "#{Time.now} Register Vm (id: #{myVm[:id]})"
    myVm.registerVm(true)
  end
end
