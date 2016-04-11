#
# Description: Amazon Placement
# By default amazon provides the default - security group and the best availability zone

# Security Group -
# http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-network-security.html
# If a security group is not assigned Amazon would use the default security group associated
# with your AWS account
#
# Availability Zone -
# http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html
# "When you launch an instance, you can optionally specify an Availability Zone in the region that you are using.
#  If you do not specify an Availability Zone, we select one for you. When you launch your initial instances,
#  we recommend that you accept the default Availability Zone, because this enables us to select the
#  best Availability Zone for you based on system health and available capacity. If you launch additional
#  instances, only specify an Availability Zone if your new instances must be close to, or separated from,
#  your running instances."
#
#
# VPC & Subnet
# For C4 and T2 instances we have to provide VPC and Subnet.
# http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/t2-instances.html
# Read section marked "EC2-VPC-only Support"
# For other instance types EC2 provides the defaults.
# This method checks the instance types and sets the VPC and subnet for T2 and C4 instances
#

def set_property(prov, image, list_method, property)
  return if prov.get_option(property)
  result = prov.send(list_method)
  $evm.log("debug", "#{property} #{result.inspect}")
  object = result.try(:first)
  return unless object

  prov.send("set_#{property}", object)
  $evm.log("info", "Image=[#{image.name}] #{property}=[#{object.name}]")
end

# Get variables
prov     = $evm.root["miq_provision"]
image    = prov.vm_template
raise "Image not specified" if image.nil?

instance_id    = prov.get_option(:instance_type)
raise "Instance Type not specified" if instance_id.nil?
flavor         = $evm.vmdb('flavor').find(instance_id)
$evm.log("debug", "instance id=#{instance_id} name=#{flavor.try(:name)}")

if flavor.try(:cloud_subnet_required)
  $evm.log("info", "Setting VPC parameters for instance type=[#{flavor.name}]")
  set_property(prov, image, :eligible_cloud_networks, :cloud_network)
  set_property(prov, image, :eligible_cloud_subnets,  :cloud_subnet)
else
  $evm.log("info", "Using EC2 for default placement of instance type=[#{flavor.try(:name)}]")
end
