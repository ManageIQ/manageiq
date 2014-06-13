$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../../lib/util")
$:.push("#{File.dirname(__FILE__)}/../../lib/metadata/VMMount")
$:.push("#{File.dirname(__FILE__)}/../../lib/metadata/linux")

require 'ostruct'
require 'MiqDisk'
require 'miq-logger'
require 'VMMount'
require 'LinuxPackages'
require 'LinuxUsers'

module MiqTest
    
    def self.test(args, cfg)
        $miqHostCfg = cfg
        $log = MIQLogger.get_log(cfg , __FILE__)
        vmHDImage = args[0]
        puts "MiqTest: disk file = #{vmHDImage}"

        diskInfo = OpenStruct.new
        diskInfo.fileName = vmHDImage

        disk = MiqDisk.getDisk(diskInfo)

        if !disk
            puts "Failed to open disk"
            exit(1)
        end

        puts "Disk type: #{disk.diskType}"
        puts "Disk partition type: #{disk.partType}"
        puts "Disk block size: #{disk.blockSize}"
        puts "Disk start LBA: #{disk.lbaStart}"
        puts "Disk end LBA: #{disk.lbaEnd}"
        puts "Disk start byte: #{disk.startByteAddr}"
        puts "Disk end byte: #{disk.endByteAddr}"

        parts = disk.getPartitions

        exit(0) if !parts

        i = 1
        parts.each do |p|
            puts "\nPartition #{i}:"
            puts "\tDisk type: #{p.diskType}"
            puts "\tPart partition type: #{p.partType}"
            puts "\tPart block size: #{p.blockSize}"
            puts "\tPart start LBA: #{p.lbaStart}"
            puts "\tPart end LBA: #{p.lbaEnd}"
            puts "\tPart start byte: #{p.startByteAddr}"
            puts "\tPart end byte: #{p.endByteAddr}"
            i += 1
        end

        disk.close
        
        return
        #
        # Linux Package Test.
        #
        
        vmMnt = VMMount.new(vmHDImage)
        raise "Could not mount drive" unless vmMnt.mounted?
        begin
            fs = vmMnt.getMountDrive
        
            puts "FS type: #{fs.fsType}"
            return if fs.fsType != "Ext3"
            
            pkgs = MiqLinux::Packages.new(fs)
            doc = pkgs.toXml
            doc.write($stdout, 4)
            puts
            
            users = MiqLinux::Users.new(fs)
            doc = users.toXml
            doc.write($stdout, 4)
            puts
        ensure
            vmMnt.unMountImage
        end
    end
    
end