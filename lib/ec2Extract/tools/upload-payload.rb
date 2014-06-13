
require 'rubygems'
require 'optparse'
require 'aws-sdk'
require_relative "../credentials"
require_relative "../Ec2Payload"

load File.join(File.dirname(__FILE__), 'payload_template.rb')

bucket			= "miq-extract"
verbose			= false
numPayload		= nil
maxItem			= nil
imageId			= nil
instanceId		= nil
ownerId			= []
executableBy	= []
cmdName			= File.basename($0)

#
# Process command line args.
#
OptionParser.new do |opts|
	opts.banner = "Usage: #{cmdName} [options]"

	opts.on('-b', '--bucket ARG', "The S3 bucket where the payloads are to be stored")	do |b|
		bucket = b
	end
	opts.on('-n', '--numpayload ARG', Integer, "The number of payloads to generate")	do |np|
		raise OptionParser::ParseError.new("--numpayload and --maxitem are mutually exclusive") if maxItem
		numPayload = np
	end
	opts.on('-m', '--maxitem ARG', Integer, "The maximum number of items per payload")	do |mi|
		raise OptionParser::ParseError.new("--numpayload and --maxitem are mutually exclusive") if numPayload
		maxItem = mi
	end
	opts.on('--image-id ARG', "Images to process: all | <image_id>")	do |id|
		raise OptionParser::ParseError.new("all and <image_id> are mutually exclusive") if imageId == "all"
		if id == "all"
			raise OptionParser::ParseError.new("all and <image_id> are mutually exclusive") if imageId
			imageId = id
		else
			imageId = [] if !imageId
			imageId << id
		end
	end
	opts.on('--instance-id ARG', "Instances to process: all | <instance_id>")	do |id|
		raise OptionParser::ParseError.new("all and <instance_id> are mutually exclusive") if instanceId == "all"
		if id == "all"
			raise OptionParser::ParseError.new("all and <instance_id> are mutually exclusive") if instanceId
			instanceId = id
		else
			instanceId = [] if !instanceId
			instanceId << id
		end
	end
	opts.on('--owner-id ARG', "Filter image list by given owner ID")	do |oid|
		ownerId << oid
	end
	opts.on('--executable-by ARG', "Filter image list by execute access")	do |eb|
		executableBy << eb
	end
	opts.on('-v', '--verbose', "Verbose output")	do
		verbose = true
	end

	begin
		opts.parse!(ARGV)
	rescue OptionParser::ParseError => perror
		$stderr.puts cmdName + ": " + perror.to_s
		$stderr.puts
		$stderr.puts opts.to_s
		exit 1
	end
end

numPayload = 1 if !numPayload && !maxItem

if imageId.kind_of?(String)
	if imageId == "all"
		imageId = []
	else
		imageId	= imageId.to_a
	end
end
if instanceId.kind_of?(String)
	if instanceId == "all"
		instanceId = []
	else
		instanceId	= instanceId.to_a
	end
end

begin
	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)

	imageLocs = []
	if imageId
		# imagesSet = ec2.describe_images(:image_id=>imageId, :owner_id=>ownerId, :executable_by=>executableBy).imagesSet
		# imagesSet = ec2.images.with_owner(:amazon).executable_by(:all)
		imagesSet = ec2.images.with_owner(:self)

		imagesSet.each do |ami|
			next if ami.type	!= :machine
			next if ami.state	!= :available
			next if ami.platform && ami.platform.casecmp("windows") == 0
		
			imageLocs << ami.location
		end
	end

	instanceIds = []
	if instanceId
		ri = ec2.describe_instances(:instance_id => [instanceId])
		ri.reservationSet.item.each do |rs|
			rs.instancesSet.item.each { |i| instanceIds << i.instanceId }
		end
	end

	nitem = imageLocs.size + instanceIds.size
	if maxItem
		numPayload = nitem / maxItem + 1
	else
		maxItem = (nitem / numPayload) + 1
	end
	last = nitem - (maxItem * (numPayload - 1))
	
	plId = "%10.6f" % Time.now.utc.to_f
	puts "Payload ID: #{plId}"

	if verbose
		puts
		puts "Bucket:                #{bucket}"
		puts "Images:                #{imageLocs.size}"
		puts "Instances:             #{instanceIds.size}"
		puts "Total:                 #{nitem}"
		puts
		puts "Items per payload:     #{maxItem}"
		puts "Payloads:              #{numPayload}"
		puts "last:                  #{last}"
		puts
	end
	
	# exit

	AWS.config(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)
	
	bucketObj = AWS::S3.new.buckets[bucket]

	numPayload.times do |n|
		pn = "payloads/%s/%05d" % [plId, (n+1)]
		puts					if verbose
		puts "Processing #{pn}"	if verbose
		$payload[:manifests] = []
		$payload[:instances] = []
	
		n = 0
		loop do
			break if n >= maxItem
		
			if !imageLocs.empty? && !instanceIds.empty?
				if n % 2 == 0
					img = imageLocs.shift
					puts "\tAdding image: #{img}"		if verbose
					$payload[:manifests] << img
				else
					inst = instanceIds.shift
					puts "\tAdding instance: #{inst}"	if verbose
					$payload[:instances] << inst
				end
				n += 1
				next
			end
		
			if !imageLocs.empty?
				img = imageLocs.shift
				puts "\tAdding image: #{img}"		if verbose
				$payload[:manifests] << img
				n += 1
			elsif !instanceIds.empty?
				inst = instanceIds.shift
				puts "\tAdding instance: #{inst}"	if verbose
				$payload[:instances] << inst
				n += 1
			else
				break
			end
		end
		
		payloadStr = Ec2Payload.encode($payload)
		bucketObj.objects.create(pn, payloadStr, :content_type => "text/plain")
	end
rescue => err
	$stderr.puts err.to_s
	$stderr.puts err.backtrace.join("\n")
end
