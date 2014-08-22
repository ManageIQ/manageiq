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
