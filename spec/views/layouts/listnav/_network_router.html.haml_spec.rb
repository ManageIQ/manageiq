include QuadiconHelper

describe "layouts/listnav/_network_router.html.haml" do
  before :each do
    set_controller_for_view("network_router")
    assign(:panels, "ems_prop" => true, "ems_rel" => true)
    allow(view).to receive(:truncate_length).and_return(15)
    allow(view).to receive(:role_allows).and_return(true)
  end

  ["openstack"].each do |t|
    before :each do
      allow_any_instance_of(User).to receive(:get_timezone).and_return(Time.zone)
      provider        = FactoryGirl.create("ems_#{t}".to_sym)
      security_group  = FactoryGirl.create("security_group_#{t}".to_sym,
                                           :ext_management_system => provider.network_manager,
                                           :name                  => 'A test')
      vm              = FactoryGirl.create("vm_#{t}".to_sym)
      network         = FactoryGirl.create("cloud_network_#{t}".to_sym)
      subnet          = FactoryGirl.create("cloud_subnet_#{t}".to_sym,
                                           :cloud_network         => network,
                                           :ext_management_system => provider.network_manager)
      @network_router = FactoryGirl.create("network_router_#{t}".to_sym,
                                           :cloud_subnets         => [subnet],
                                           :ext_management_system => provider.network_manager)
      floating_ip     = FactoryGirl.create("floating_ip_#{t}".to_sym,
                                           :ext_management_system => provider.network_manager)
      vm.network_ports << network_port = FactoryGirl.create("network_port_#{t}".to_sym,
                                                            :device          => vm,
                                                            :security_groups => [security_group],
                                                            :floating_ip     => floating_ip)

      FactoryGirl.create(:cloud_subnet_network_port, :cloud_subnet => subnet, :network_port => network_port)
    end

    context "for #{t}" do
      it "relationships links uses restful path in #{t.camelize}" do
        @record = @network_router
        render
        expect(response).to include("Show this Network Router&#39;s parent Network Provider\" href=\"/ems_network/show/#{@record.ext_management_system.id}\">")
        expect(response).to include("Show all Instances\" onclick=\"return miqCheckForChanges()\" href=\"/network_router/show/#{@record.id}?display=instances\">")
      end
    end
  end
end
