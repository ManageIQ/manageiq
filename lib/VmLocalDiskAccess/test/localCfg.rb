$:.push("#{File.dirname(__FILE__)}/../../util")
$:.push("#{File.dirname(__FILE__)}/../../VolumeManager")
$:.push("#{File.dirname(__FILE__)}/../../fs")
$:.push("#{File.dirname(__FILE__)}/../../metadata/VmConfig")

require 'rubygems'
require 'log4r'
require 'miq-xml'
require 'runcmd'
require 'VmConfig'
require 'MiqNativeVolumeManager'
require 'MiqMountManager'

module MiqNativeMountManager
	
	LSHW = "lshw"
	
	def self.mountVolumes
		lshwXml = MiqUtil.runcmd("#{LSHW} -xml")
		nodeHash = Hash.new { |h, k| h[k] = Array.new }
		doc = MiqXml.load(lshwXml)
		doc.find_match("//node").each { |n| nodeHash[n.attributes["id"].split(':', 2)[0]] << n }

		hardware = ""

		nodeHash["disk"].each do |d|
			diskid = d.find_first('businfo').get_text.to_s
			next if !diskid
			sn = d.find_first('size')
			# If there's no size node, assume it's a removable drive.
			next if !sn
			busType, busAddr = diskid.split('@', 2)
			if busType == "scsi"
				f1, f2 = busAddr.split(':', 2)
				f2 = f2.split('.')[1]
				busAddr = "#{f1}:#{f2}"
			else
				busAddr['.'] = ':'
			end
			diskid = busType + busAddr
			filename = d.find_first('logicalname').get_text.to_s
			hardware += "#{diskid}.present = \"TRUE\"\n"
			hardware += "#{diskid}.filename = \"#{filename}\"\n"
		end
		
		cfg = VmConfig.new(hardware)
		volMgr = MiqNativeVolumeManager.new(cfg)
		
		return(MiqMountManager.mountVolumes(volMgr, cfg))
	end
	
end # module MiqNativeMountManager

if __FILE__ == $0
	#
	# Formatter to output log messages to the console.
	#
	class ConsoleFormatter < Log4r::Formatter
		def format(event)
			(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
		end
	end
	$log = Log4r::Logger.new 'toplog'
	$log.level = Log4r::DEBUG
	Log4r::StderrOutputter.new('err_console', :formatter=>ConsoleFormatter)
	$log.add 'err_console'

	puts "Log debug?: #{$log.debug?}"

	rootTrees = MiqNativeMountManager.mountVolumes
	
	if rootTrees.nil? || rootTrees.empty?
		puts "No root filesystems detected"
		exit
	end

	$miqOut = $stdout
	rootTrees.each do |r|
		r.toXml(nil)
	end

	rootTree = rootTrees[0]

	if rootTree.guestOS == "Linux"
		puts
		puts "Files in /:"
		rootTree.dirForeach("/") { |f| puts "\t#{f}" }

		puts
		puts "All files in /test_mount:"
		rootTree.findEach("/test_mount") { |f| puts "\t#{f}" }
	elsif rootTree.guestOS == "Windows"
		puts
		puts "Files in C:/"
		rootTree.dirForeach("C:/") { |f| puts "\t#{f}" }
		
		["E:/", "F:/"].each do |drive|
			puts
			puts "All files in #{drive}"
			rootTree.findEach(drive) { |f| puts "\t#{f}" }
		end
	else
		puts "Unknown guest OS: #{rootTree.guestOS}"
	end
end

