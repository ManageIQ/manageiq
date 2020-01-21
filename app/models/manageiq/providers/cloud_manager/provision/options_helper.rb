module ManageIQ::Providers::CloudManager::Provision::OptionsHelper
  def dest_availability_zone
    @dest_availability_zone ||= AvailabilityZone.find_by(:id => get_option(:dest_availability_zone))
  end

  def guest_access_key_pair
    @guest_access_key_pair ||= ManageIQ::Providers::CloudManager::AuthKeyPair.find_by(:id => get_option(:guest_access_key_pair))
  end

  def security_groups
    @security_groups ||= SecurityGroup.where(:id => options[:security_groups])
  end

  def instance_type
    @instance_type ||= Flavor.find_by(:id => get_option(:instance_type))
  end

  def floating_ip
    @floating_ip ||= FloatingIp.find_by(:id => get_option(:floating_ip_address))
  end

  def cloud_network
    @cloud_network ||= CloudNetwork.find_by(:id => get_option(:cloud_network))
  end

  def cloud_subnet
    @cloud_subnet ||= CloudSubnet.find_by(:id => get_option(:cloud_subnet))
  end
end
