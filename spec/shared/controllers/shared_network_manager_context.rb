shared_context :shared_network_manager_context do |t|
  before :each do
    @provider       = FactoryGirl.create("ems_#{t}".to_sym,
                                         :name => "Cloud Manager")
    @security_group = FactoryGirl.create("security_group_#{t}".to_sym,
                                         :ext_management_system => @provider.network_manager,
                                         :name                  => 'Security Group')
    @vm             = FactoryGirl.create("vm_#{t}".to_sym,
                                         :name => "Instance")
    if t == 'openstack'
      @cloud_network        = FactoryGirl.create("cloud_network_private_#{t}".to_sym,
                                                 :name => "Cloud Network")
      @cloud_network_public = FactoryGirl.create("cloud_network_public_#{t}".to_sym,
                                                 :name => "Cloud Network Public")
    else
      @cloud_network        = FactoryGirl.create("cloud_network_#{t}".to_sym,
                                                 :name => "Cloud Network")
      @cloud_network_public = nil
    end

    @network_router = FactoryGirl.create("network_router_#{t}".to_sym,
                                         :cloud_network => @cloud_network_public,
                                         :name          => "Network Router")

    @cloud_subnet = FactoryGirl.create("cloud_subnet_#{t}".to_sym,
                                       :network_router        => @network_router,
                                       :cloud_network         => @cloud_network,
                                       :ext_management_system => @provider.network_manager,
                                       :name                  => "Cloud Subnet")

    @floating_ip = FactoryGirl.create("floating_ip_#{t}".to_sym,
                                      :ext_management_system => @provider.network_manager)
    @vm.network_ports << @network_port = FactoryGirl.create("network_port_#{t}".to_sym,
                                                            :name            => "eth0",
                                                            :device          => @vm,
                                                            :security_groups => [@security_group],
                                                            :floating_ip     => @floating_ip)
    FactoryGirl.create(:cloud_subnet_network_port, :cloud_subnet => @cloud_subnet, :network_port => @network_port)
  end
end
