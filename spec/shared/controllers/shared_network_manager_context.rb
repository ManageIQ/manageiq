shared_context :shared_network_manager_context do |t|
  before :each do
    @ems_cloud      = FactoryGirl.create("ems_#{t}".to_sym,
                                         :name => "Cloud Manager")
    @ems            = @ems_cloud.network_manager
    @security_group = FactoryGirl.create("security_group_#{t}".to_sym,
                                         :ext_management_system => @ems,
                                         :name                  => 'Security Group')
    @vm             = FactoryGirl.create("vm_#{t}".to_sym,
                                         :name                  => "Instance",
                                         :ext_management_system => @ems)
    if t == 'openstack'
      @cloud_network        = FactoryGirl.create("cloud_network_private_#{t}".to_sym,
                                                 :name                  => "Cloud Network",
                                                 :ext_management_system => @ems)
      @cloud_network_public = FactoryGirl.create("cloud_network_public_#{t}".to_sym,
                                                 :name                  => "Cloud Network Public",
                                                 :ext_management_system => @ems)
    else
      @cloud_network        = FactoryGirl.create("cloud_network_#{t}".to_sym,
                                                 :name                  => "Cloud Network",
                                                 :ext_management_system => @ems)
      @cloud_network_public = nil
    end

    @network_router = FactoryGirl.create("network_router_#{t}".to_sym,
                                         :cloud_network         => @cloud_network_public,
                                         :name                  => "Network Router",
                                         :ext_management_system => @ems)
    @cloud_subnet   = FactoryGirl.create("cloud_subnet_#{t}".to_sym,
                                         :network_router        => @network_router,
                                         :cloud_network         => @cloud_network,
                                         :ext_management_system => @ems,
                                         :name                  => "Cloud Subnet")
    @child_subnet   = FactoryGirl.create("cloud_subnet_#{t}".to_sym,
                                         :name                  => "Child Cloud Subnet",
                                         :parent_cloud_subnet   => @cloud_subnet,
                                         :ext_management_system => @ems)
    @floating_ip    = FactoryGirl.create("floating_ip_#{t}".to_sym,
                                         :address               => "192.0.2.1",
                                         :ext_management_system => @ems)

    @vm.network_ports << @network_port = FactoryGirl.create("network_port_#{t}".to_sym,
                                                            :name                  => "eth0",
                                                            :mac_address           => "06:04:25:40:8e:79",
                                                            :device                => @vm,
                                                            :security_groups       => [@security_group],
                                                            :floating_ip           => @floating_ip,
                                                            :ext_management_system => @ems)
    FactoryGirl.create(:cloud_subnet_network_port,
                       :cloud_subnet => @cloud_subnet,
                       :network_port => @network_port,
                       :address      => "10.10.0.2")

    if %w(amazon).include? t
      @load_balancer              = FactoryGirl.create("load_balancer_#{t}".to_sym,
                                                       :ems_id => @ems.id,
                                                       :name   => "Load Balancer")
      @load_balancer_2            = FactoryGirl.create("load_balancer_#{t}".to_sym)
      @load_balancer_pool         = FactoryGirl.create("load_balancer_pool_#{t}".to_sym)
      @load_balancer_listener     = FactoryGirl.create("load_balancer_listener_#{t}".to_sym,
                                                       :load_balancer => @load_balancer)
      @load_balancer_pool_member  = FactoryGirl.create("load_balancer_pool_member_#{t}".to_sym,
                                                       :vm => @vm)
      @load_balancer_health_check = FactoryGirl.create("load_balancer_health_check_#{t}".to_sym)

      FactoryGirl.create("load_balancer_listener_pool".to_sym,
                         :load_balancer_pool     => @load_balancer_pool,
                         :load_balancer_listener => @load_balancer_listener)
      FactoryGirl.create("load_balancer_pool_member_pool".to_sym,
                         :load_balancer_pool        => @load_balancer_pool,
                         :load_balancer_pool_member => @load_balancer_pool_member)
      FactoryGirl.create("load_balancer_health_check_member".to_sym,
                         :load_balancer_health_check => @load_balancer_health_check,
                         :load_balancer_pool_member  => @load_balancer_pool_member)
    end
  end
end
