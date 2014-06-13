require 'aws-sdk'
require '../credentials'

IMAGE_LOCATION				= "rpo-work/miq-test.img.manifest.xml"
KEY_NAME					= "rpo"
AVAILABILITY_ZONE			= "us-east-1b"
SECURITY_GROUP				= "webserver"

$options_hash = {
	# How many instances to request.
	# By default one instance is requested.
	# You can specify this either as an integer or as a Range,
	# to indicate the minimum and maximum number of instances to run.
	:count									=> 1,
	
	# The name or ARN of an IAM instance profile.
	# This provides credentials to the EC2 instance(s) via the instance metadata service. 
	# :iam_instance_profile					=> nil,
	
	# This must be a hash; the keys are device names to map,
	# and the value for each entry determines how that device is mapped.
	# :block_device_mappings					=> nil,
	
	# Setting this to true enables CloudWatch monitoring
	# on the instances once they are started.
	:monitoring_enabled						=> true,
	
	# Specifies the availability zone where the instance should run.
	# Without this option, EC2 will choose an availability zone for you. 
	:availability_zone						=> nil,
	
	# ID of the AMI you want to launch.
	:image_id								=> nil,
	
	# The name of the key pair to use.
	# Note: Launching public images without a key pair ID will leave them inaccessible.
	# :key_name								=> "rpo",
	
	# A KeyPair that should be used when launching an instance.
	:key_pair								=> nil,
	
	# Security groups are used to determine network access rules for the instances.
	# :security_groups can be a single value or an array of values.
	# Values should be group name strings or SecurityGroup objects.
	:security_groups						=> nil,
	
	# Security groups are used to determine network access rules for the instances.
	# :security_group_ids accepts a single ID or an array of security group IDs.
	# :security_group_ids						=> nil,
	
	# Arbitrary user data. You do not need to encode this value.
	# :user_data								=> nil,
	
	# The type of instance to launch, for example “m1.small”.
	:instance_type							=> "m1.small",
	
	# The ID of the kernel with which to launch the instance.
	# :kernel_id								=> nil,
	
	# The ID of the RAM disk to select.
	# Some kernels require additional drivers at launch.
	# Check the kernel requirements for information on whether you need to specify a RAM disk.
	# To find kernel requirements, refer to the Resource Center and search for the kernel ID.
	# :ramdisk_id								=> nil,
	
	#  Specifies whether you can terminate the instance using the EC2 API.
	# A value of true means you can’t terminate the instance using the API
	# (i.e., the instance is “locked”); a value of false means you can.
	# If you set this to true, and you later want to terminate the instance,
	# you must first enable API termination.
	:disable_api_termination				=> false,
	
	# Determines whether the instance stops or terminates on instance-initiated shutdown.
	# :instance_initiated_shutdown_behavior	=> nil,
	
	# The VPC Subnet (or subnet id string) to launch the instance in.
	# :subnet									=> nil,
	
	# If you’re using VPC, you can optionally use this option to assign the instance
	# a specific available IP address from the subnet (e.g., ‘10.0.0.25’).
	# This option is not valid for instances launched outside a VPC
	# (i.e. those launched without the :subnet option). 
	# :private_ip_address						=> nil,
	
	# Instances with dedicated tenancy will not share physical hardware with instances
	# outside their VPC. NOTE: Dedicated tenancy incurs an additional service charge.
	# This option is not valid for instances launched outside a VPC
	# (e.g. those launched without the :subnet option).
	# :dedicated_tenancy						=> false
}

begin

	ec2 = AWS::EC2.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)

	#
	# Given the location of the image we want to launch, find its
	# associated image object. We only do this to get the image ID,
	# which is required to launch instances of the image.
	#
	# We keep the image ID in the uid_ems column of the VMS table
	# (NOTE: not in the ems_ref column)
	# We should be able to use the value from the database to launch
	# the instance.
	#
	images = ec2.images.with_owner('self')
	image = nil
	images.each do |ami|
		next unless ami.location == IMAGE_LOCATION
		image = ami
		break
	end
	raise "Image: #{IMAGE_LOCATION} not found" unless image
	puts
	puts "Found image, image id = #{image.id}"
	$options_hash[:image_id] = image.id
	
	#
	# Find the key pair to use when launching the image.
	# You can pass the key pair name through the :key_name option,
	# or pass the key pair object via :key_pair.
	# See dumpKeyPairs.rb for an example of how to obtain a list
	# of key pairs available for use.
	#
	raise "Key pair: #{KEY_NAME} not found" unless (key_pair = ec2.key_pairs[KEY_NAME])
	puts
	puts "Found key pair #{key_pair.name}"
	$options_hash[:key_pair] = key_pair
	
	#
	# Check to see if the given availability zone exists.
	# We only need to pass the name, so we could just call the API with
	# the given name and let it do the validation. However, the following
	# code can also be used to obtain a list of availibility zones that
	# can be presented to the user.
	#
	availability_zone = nil
	ec2.availability_zones.each do |az|
		next unless az.name == AVAILABILITY_ZONE
		availability_zone = az.name
		break
	end
	raise "Availability zone: #{AVAILABILITY_ZONE} not found" unless availability_zone
	puts
	puts "Found availability zone #{availability_zone}"
	$options_hash[:availability_zone] = availability_zone
	
	#
	# Check to see if the given security group exists.
	# We only need to pass the name, so we could just call the API with
	# the given name and let it do the validation. However, the following
	# code can also be used to obtain a list of availibility zones that
	# can be presented to the user.
	#
	security_group = nil
	ec2.security_groups.each do |sg|
		next unless sg.name == SECURITY_GROUP
		security_group = sg.name
		break
	end
	raise "Security group: #{SECURITY_GROUP} not found" unless security_group
	puts
	puts "Found security group #{security_group}"
	$options_hash[:security_groups] = security_group
	
	#
	# Instances can be launched in either of two ways:
	# through AWS::EC2::InstanceCollection.create
	# or AWS::EC2::Image.run_instance
	# An example of each follows.
	#
	
	#
	# Start an image through AWS::EC2::InstanceCollection.create
	#
	puts
	puts "Starting instance of image #{image.id} via InstanceCollection.create..."
	instance = ec2.instances.create($options_hash)
	sleep 1 while instance.status == :pending
	puts "Instance #{instance.id} - #{instance.status}"
	puts
	puts "Terminating instance: #{instance.id}..."
	instance.terminate
	sleep 1 while instance.status == :shutting_down
	puts "Instance #{instance.id} - #{instance.status}"
	
	#
	# Start an image through AWS::EC2::Image.run_instance
	#
	puts
	puts "Starting instance of image #{image.id} via Image.run_instance..."
	instance = image.run_instance($options_hash)
	sleep 1 while instance.status == :pending
	puts "Instance #{instance.id} - #{instance.status}"
	puts
	puts "Terminating instance: #{instance.id}..."
	instance.terminate
	sleep 1 while instance.status == :shutting_down
	puts "Instance #{instance.id} - #{instance.status}"
	
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
