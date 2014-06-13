$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../../MiqVm")

require 'rubygems'
require 'aws-sdk'
require 'log4r'
require 'yaml'
require 'MiqVm'
require 'Ec2InstanceMetadata'
require 'MiqEc2EbsImage'
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

	miq_image = nil
	ec2.images.with_owner('self').each do |image|
		next unless image.root_device_type == :ebs
		# next if image.id == myImage.id
		
		$log.info "Target image: #{image.location} (#{image.id})"
		miq_image = MiqEc2EbsImage.new(image, myInstance, ec2)
		
		$log.info "*** Mapping volumes..."
		unless miq_image.mapVolumes
			$log.info "*** Could not map volumes"
			$log.info ""
			next
		end
		$log.info "*** Mapping volumes DONE"
		cfg = miq_image.getCfg
		cfg.each_line { |l| $log.info "    #{l.chomp}" }
		`ls -l /dev/xvd*`.each_line { |l| $log.info "        #{l.chomp}" }
		
		extractHash = {}
		begin
			miqVm = MiqVm.new(cfg)
			CATEGORIES.each do |cat|
				xml = miqVm.extract(cat)
				extractHash[cat] = xml.to_xml.to_s
			end
		rescue => err
			$log.error err.to_s
			$log.error err.backtrace.join("\n")
		ensure
			miqVm.unmount if miqVm
		end
		
		yml = YAML.dump(extractHash)
		$log.info "Extracted data yaml size: #{yml.bytesize} (#{yml.bytesize/1024.0}kb)"
		
		$log.info "*** Un-mapping volumes..."
		miq_image.unMapVolumes
		miq_image = nil
		$log.info "*** Un-mapping volumes DONE"
		$log.info ""
	end
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	# miq_image.unMapVolumes if miq_image
end
