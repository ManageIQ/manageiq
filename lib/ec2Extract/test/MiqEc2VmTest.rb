$:.push(File.dirname(__FILE__))
$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../MiqEc2Vm")

require 'rubygems'
require 'log4r'
require 'log4r/configurator'

#
# We must do this before anything accesses log4r.
#
module Log4r
	Configurator.custom_levels(:DEBUG, :INFO, :WARN, :ERROR, :FATAL, :COPY)
end

require 'aws-sdk'
require 'Ec2InstanceMetadata'
require 'Ec2Payload'
require 'MiqEc2Vm'
require_relative '../credentials'

class LogFormatter < Log4r::Formatter
	@@prog = File.basename(__FILE__, ".*")
	def format(event)
		"#{Log4r::LNAMES[event.level]} [#{datetime}] -- #{@@prog}: " +
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end

	private

	def datetime
		time = Time.now.utc
		time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d" % time.usec
	end
end

class CopyFormatter < Log4r::Formatter
	def format(event)
		event.data.chomp + "\n"
	end
end

logFile	= File.join(Dir.tmpdir, "miq.log")
lfIo = File.new(logFile, "w+")

$log = Log4r::Logger.new 'toplog'
$log.level = Log4r::DEBUG

lfo = Log4r::IOOutputter.new('log_file', lfIo, :formatter=>LogFormatter)
lfo.only_at(Log4r::DEBUG, Log4r::INFO, Log4r::WARN, Log4r::ERROR, Log4r::FATAL)
$log.add 'log_file'

lco = Log4r::IOOutputter.new('log_copy', lfIo, :formatter=>CopyFormatter)
lco.only_at(Log4r::COPY)
$log.add 'log_copy'

eso = Log4r::StderrOutputter.new('err_console', :formatter=>LogFormatter)
eso.only_at(Log4r::DEBUG, Log4r::INFO, Log4r::WARN, Log4r::ERROR, Log4r::FATAL)
$log.add 'err_console'

eco = Log4r::StderrOutputter.new('err_copy', :formatter=>CopyFormatter)
eco.only_at(Log4r::COPY)
$log.add 'err_copy'

$stderr.sync = true

CATEGORIES	= ["accounts", "services", "software", "system"]

begin
	
	eim = Ec2InstanceMetadata.new
	instanceArgs = Ec2Payload.userData
	
	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)
	myInstance	= ec2.instances[eim.metadata('instance-id')]
	
	# ami-edad1984	AMI (EBS)
	# i-06359e7c	Instance (EBS)
	# ami-20e90e49	AMI (instance_store)
	# i-07f1b47c	Instance (instance_store)
	[ 'ami-edad1984', 'i-06359e7c', 'ami-20e90e49', 'i-07f1b47c' ].each do |ec2_id|
		ec2Vm = MiqEc2Vm.new(ec2_id, myInstance, ec2, instanceArgs)
	
		$log.info "MiqEc2Vm: #{ec2Vm.class.name}"
		CATEGORIES.each do |cat|
			xml = ec2Vm.extract(cat)
			puts "----- MIQ START -----: #{cat}"
			xml.to_xml.write($stdout, 4)
			puts
			puts "----- MIQ END -----: #{cat}"
		end
		ec2Vm.unmount
	end
	
rescue => err
	puts err.to_s
    puts err.backtrace.join("\n")
end
