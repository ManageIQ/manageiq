class MiqVmFsUtil
    
    attr_reader :fs
    
    def initialize(fs)
        @fs = fs
    end
    
    #
    # Copy files out of the VM to the host.
    # First-level files only - from "formDir" to "toDir"
    #
    def flatDirCopyOut(fromDir, toDir)
        raise "MiqVmFsUtil::flatDirCopyOut - #{fromDir} does not exist." if !@fs.fileExists?(fromDir)
        raise "MiqVmFsUtil::flatDirCopyOut - #{fromDir} is not a directory." if !@fs.fileDirectory?(fromDir)
        
        Dir.mkdir(toDir) if !File.exist?(toDir)
        raise "MiqVmFsUtil::flatDirCopyOut - #{toDir} is not a directory." if !File.directory?(toDir)
        
        @fs.chdir(fromDir)
        @fs.dirForeach do |ff|
            next if ff == "." || ff == ".."
            next if !@fs.fileFile?(ff)
            
            @fs.fileOpen(ff) do |ffo|
                tf = File.join(toDir, ff)
                tfo = File.new(tf, "wb")
                buf = ffo.read
                while (buf = ffo.read(1024))
                    tfo.write(buf)
                end
                tfo.close
            end
        end
    end
    
    def find(dir)
        foundFiles = []
        
        dirEntries = @fs.dirEntries(dir)
        dirEntries.each do |de|
            next if de == '.' || de == '..'
            fp = File.join(dir, de)
            foundFiles << fp
            foundFiles.concat(find(fp)) if @fs.fileDirectory?(fp)
        end
        return(foundFiles)
    end
    
    def findEach(dir, &block)
        dirEntries = @fs.dirEntries(dir)
        dirEntries.each do |de|
            next if de == '.' || de == '..'
            fp = File.join(dir, de)
            yield(fp)
            findEach(fp, &block) if @fs.fileDirectory?(fp)
        end
    end
    
end # class MiqVmFsUtil

if __FILE__ == $0
    $:.push("#{File.dirname(__FILE__)}/../metadata/util/win32")
    $:.push("#{File.dirname(__FILE__)}/../MiqVm")
    
    require 'rubygems'
    require 'log4r'
    require 'boot_info_win'
    require 'MiqVm'
    require "MiqFS"
    
    #
    # *** Change this to point to the VM directory.
    #
    vmDir = File.join(ENV.fetch("HOME", '.'), 'VMs')
    puts "vmDir = #{vmDir}"
    
    class ConsoleFormatter < Log4r::Formatter
    	def format(event)
    		(event.data.kind_of?(String) ? event.data : event.data.inspect)
    	end
    end

    toplog = Log4r::Logger.new 'toplog'
    Log4r::StderrOutputter.new('err_console', :level=>Log4r::ERROR, :formatter=>ConsoleFormatter)
    toplog.add 'err_console'
    $log = toplog if $log.nil?
    
    #
    # *** Test start
    #
    
    # vmdk = File.join(vmDir, "redhat-v3.vmwarevm/redhat-v3.vmdk")
    vmCfg = File.join(vmDir, "redhat-v3.vmwarevm/redhat-v3.vmx")
    # vmCfg = File.join(vmDir, "UbuntuDev.vmwarevm/UbuntuDev.vmx")
    # vmCfg = File.join(vmDir, "Red Hat Linux.vmwarevm/Red Hat Linux.vmx")
    # vmCfg = File.join(vmDir, "MIQ Server Appliance - Ubuntu MD - small/MIQ Server Appliance - Ubuntu.vmx")
    # vmCfg = File.join(vmDir, "winxpDev.vmwarevm/winxpDev.vmx")
    # puts "VM config file: #{vmCfg}"
    
    # ost = OpenStruct.new
    # ost.fileName = vmdk
    # d = MiqDisk.getDisk(ost)
    # parts = d.getPartitions
    
    # raise "expecting 3 partitions, got #{parts.length}" if parts.length != 3
    
    # fs = MiqFS.getFS(parts[1])
    # raise "couldn't mount FS" if !fs
    
    # vmfsu = MiqVmFsUtil.new(fs)
    
    vm = MiqVm.new(vmCfg)
    raise "No OSs detected" if vm.vmRootTrees.length == 0
    
    vmfsu = MiqVmFsUtil.new(vm.vmRootTrees[0])
    # vmfsu.flatDirCopyOut("/var/lib/rpm", "rpm_test_dir")
    vmfsu.fs.chdir("/var/lib")
    vmfsu.findEach(".") { |f| puts f }
    
    vm.unmount
end
