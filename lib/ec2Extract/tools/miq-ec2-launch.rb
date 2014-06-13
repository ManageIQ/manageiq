
require 'rubygems'
require 'log4r'
require 'optparse'
require 'net/ssh'
require 'net/sftp'
require 'aws-sdk'
require File.join(File.dirname(__FILE__), '../Ec2Payload')
require File.join(File.dirname(__FILE__), '../S3FS')
require 'pp'
require_relative "../credentials"
# AMI = "rpo-images/miq-ec2-proto.img.manifest.xml"
# AMI = "rpo-images/miq-ec2-extract.img.manifest.xml"
# AMI = "rpo-images/ubuntu10.04/ubuntu10.04-rvm-ruby1.9.manifest.xml"
AMI = "rpo-images/ubuntu10.04/miq-extract-work3.manifest.xml"

timeStamp = Time.now.utc
timeStampStr = "TS:" + (timeStamp.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d" % timeStamp.usec).to_str

puts "Timestamp: #{timeStampStr}"

args = {
	:access_key_id		=> AMAZON_ACCESS_KEY_ID,
	:secret_access_key	=> AMAZON_SECRET_ACCESS_KEY,
	:timeStamp			=> timeStampStr,
	:miq_bucket_in		=> "miq-extract",
	:miq_bucket_out		=> "miq-extract",
	:payload			=> "miq-payload-0001",
	:categories			=> ["accounts", "services", "software", "system"],
	:log_level			=> "DEBUG"
}

bucket			= "miq-extract"
logLevel		= "info"
verbose			= false
payloadId		= nil
payloads		= nil
categories		= nil
cmdName			= File.basename($0)

#
# Process command line args.
#
OptionParser.new do |opts|
	opts.banner = "Usage: #{cmdName} [options]"

	opts.on('-b', '--bucket ARG', "The S3 bucket where the payloads are stored")	do |b|
		bucket = b
	end
	opts.on('--payload-id ARG', "The ID identifying the payloads to use for extraction")	do |pid|
		raise OptionParser::ParseError.new("--payload-id and --payload are mutually exclusive") if payloads
		payloadId = pid
	end
	opts.on('--payload ARG', "Specific payload to use for extraction")	do |p|
		raise OptionParser::ParseError.new("--payload-id and --payload are mutually exclusive") if payloadId
		payloads = [] if !payloads
		payloads << p
	end
	opts.on('-l', '--loglevel ARG')	do |ll|
		raise OptionParser::ParseError.new("Unrecognized log level: #{ll}") if !(/DEBUG|INFO|WARN|ERROR|FATAL/i =~ ll)
		logLevel = ll
	end
	opts.on('-v', '--verbose', "Verbose output")	do
		verbose = true
	end

	begin
		categories = opts.parse!(ARGV)
	rescue OptionParser::ParseError => perror
		$stderr.puts cmdName + ": " + perror.to_s
		$stderr.puts
		$stderr.puts opts.to_s
		exit 1
	end
end

class ConsoleFormatter < Log4r::Formatter
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

toplog = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
toplog.add 'err_console'
$log = toplog

$stdout.sync = true

args[:categories] = categories if !categories.empty?

if bucket
	args[:miq_bucket_in] = bucket
	args[:miq_bucket_out] = bucket
end

begin
	AWS.config(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)
	fs = S3FS.new(:bucket => args[:miq_bucket_in])

	if payloadId
		payloadDir = File.join("payloads", payloadId)
	
		if !fs.fileDirectory?(payloadDir)
			$stderr.puts "Unknown payload ID: #{payloadId}"
			exit(1)
		end
		payloads = Array.new
		fs.dirEntries(payloadDir).each do |pl|
			payloads << File.join(payloadDir, pl)
		end
	else
		pla = Array.new
		err = false
		payloads.each do |pl|
			if !fs.fileExists?(pl)
				$stderr.puts "Payload: #{pl} does not exist"
				err = true
			else
				pla << pl
			end
		end
		exit(1) if err
		payloads = pla
	end

	if !payloads || payloads.empty?
		$stderr.puts "No payloads provoded."
		exit(1)
	end

	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)

	images = ec2.images.with_owner('self')
	amiId = nil
	images.each do |ami|
		next unless ami.location == AMI
		amiId = ami.id
		break
	end

	if !amiId
		$stderr.puts "AMI: #{AMI} not found"
		exit 1
	end

	puts "AMI ID: #{amiId}"

	payloads.each do |p|
		puts "Starting worker for payload: #{p}"
		args[:payload] = p
		userData = Ec2Payload.encode(args)
		ri = ec2.instances.create(:image_id => amiId, :key_name => 'rpo', :availability_zone => "us-east-1b", :user_data => userData)
	end
rescue => serror
	$stderr.puts serror.to_s
	$stderr.puts serror.backtrace.join('\n')
	exit(1)
end
