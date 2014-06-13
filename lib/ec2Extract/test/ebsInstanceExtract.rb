$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../../MiqVm")

require 'rubygems'
require 'aws-sdk'
require 'log4r'
require 'MiqVm'
require 'Ec2InstanceMetadata'
require 'MiqEc2EbsInstance'
require_relative '../credentials'

class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end

toplog = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
toplog.add 'err_console'
$vim_log = $log = toplog if $log.nil?

CATEGORIES	= ["accounts", "services", "software", "system"]

begin
	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)
	eim = Ec2InstanceMetadata.new
	
	myInstance	= ec2.instances[eim.metadata('instance-id')]
	myImage		= ec2.images[myInstance.image_id]
	
	$log.info ""
	$log.info "Extractor instance: #{myInstance.id}"
	$log.info "Extractor image:    #{myImage.location} (#{myImage.id})"
	$log.info "Extractor Block device mappings:"
	myInstance.block_device_mappings.each do |k, v|
		$log.info "    #{k}:"
		$log.info "        device:\t#{v.device}"
		$log.info "        volume:\t#{v.volume.id}"
		$log.info "        status:\t#{v.status}"
	end
	$log.info ""

	miq_instance = nil
	ec2.instances.each do |instance|
		next unless instance.root_device_type == :ebs
		
		$log.info "Target instance: #{instance.image_id} (#{instance.id})"
		miq_instance = MiqEc2EbsInstance.new(instance, myInstance, ec2)
		
		$log.info "*** Mapping volumes..."
		unless miq_instance.mapVolumes
			$log.info "*** Could not map volumes"
			$log.info ""
			next
		end
		$log.info "*** Mapping volumes DONE"
		cfg = miq_instance.getCfg
		cfg.each_line { |l| $log.info "    #{l.chomp}" }
		`ls -l /dev/xvd*`.each_line { |l| $log.info "        #{l.chomp}" }
		
		begin
			miqVm = MiqVm.new(cfg)
			CATEGORIES.each do |cat|
				xml = miqVm.extract(cat)
				puts "----- MIQ START -----: #{cat}"
				xml.to_xml.write($stdout, 4)
				puts
				puts "----- MIQ END -----: #{cat}"
			end
		rescue => err
			$log.error err.to_s
			$log.error err.backtrace.join("\n")
		ensure
			miqVm.unmount if miqVm
		end
		
		$log.info "*** Un-mapping volumes..."
		miq_instance.unMapVolumes
		miq_instance = nil
		$log.info "*** Un-mapping volumes DONE"
		$log.info ""
	end
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	# miq_instance.unMapVolumes if miq_instance
end
