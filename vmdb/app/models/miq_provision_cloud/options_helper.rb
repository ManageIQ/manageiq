module MiqProvisionCloud::OptionsHelper
  def dest_availability_zone
    @dest_availability_zone ||= AvailabilityZone.where(:id => get_option(:dest_availability_zone)).first
  end

  def guest_access_key_pair
    @guest_access_key_pair ||= AuthPrivateKey.where(:id => get_option(:guest_access_key_pair)).first
  end

  def security_groups
    @security_groups ||= SecurityGroup.where(:id => options[:security_groups])
  end

  def instance_type
    @instance_type ||= Flavor.where(:id => get_option(:instance_type)).first
  end

  def floating_ip
    @floating_ip ||= FloatingIp.where(:id => get_option(:floating_ip_address)).first
  end

  def cloud_network
    @cloud_network ||= CloudNetwork.where(:id => get_option(:cloud_network)).first
  end

  def cloud_subnet
    @cloud_subnet ||= CloudSubnet.where(:id => get_option(:cloud_subnet)).first
  end
end
