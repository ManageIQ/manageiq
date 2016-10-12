describe "layouts/listnav/_load_balancer.html.haml" do
  helper(QuadiconHelper)

  before :each do
    set_controller_for_view("load_balancer")
    assign(:panels, "ems_prop" => true, "ems_rel" => true)
    allow(view).to receive(:truncate_length).and_return(15)
    allow(view).to receive(:role_allows?).and_return(true)
  end

  %w(amazon).each do |t|
    before :each do
      allow_any_instance_of(User).to receive(:get_timezone).and_return(Time.zone)
      provider                   = FactoryGirl.create("ems_#{t}".to_sym)
      @load_balancer             = FactoryGirl.create("load_balancer_#{t}".to_sym,
                                                      :name                  => "Load Balancer",
                                                      :ext_management_system => provider.network_manager)
      vm                         = FactoryGirl.create("vm_#{t}".to_sym)
      load_balancer_pool         = FactoryGirl.create("load_balancer_pool_#{t}".to_sym)
      load_balancer_listener     = FactoryGirl.create("load_balancer_listener_#{t}".to_sym,
                                                      :load_balancer => @load_balancer)
      load_balancer_pool_member  = FactoryGirl.create("load_balancer_pool_member_#{t}".to_sym,
                                                      :vm => vm)
      load_balancer_health_check = FactoryGirl.create("load_balancer_health_check_#{t}".to_sym)

      FactoryGirl.create("load_balancer_listener_pool".to_sym,
                         :load_balancer_pool     => load_balancer_pool,
                         :load_balancer_listener => load_balancer_listener)
      FactoryGirl.create("load_balancer_pool_member_pool".to_sym,
                         :load_balancer_pool        => load_balancer_pool,
                         :load_balancer_pool_member => load_balancer_pool_member)
      FactoryGirl.create("load_balancer_health_check_member".to_sym,
                         :load_balancer_health_check => load_balancer_health_check,
                         :load_balancer_pool_member  => load_balancer_pool_member)
    end

    context "for #{t}" do
      it "relationships links uses restful path in #{t.camelize}" do
        @record = @load_balancer
        render
        expect(response).to include("href=\"/load_balancer/show/#{@record.id}?display=main\">Summary")
        expect(response).to include("Show this Load Balancer&#39;s parent Network Provider\" href=\"/ems_network/#{@record.ext_management_system.id}\">")
        expect(response).to include("Show all Instances\" onclick=\"return miqCheckForChanges()\" href=\"/load_balancer/show/#{@record.id}?display=instances\">")
      end
    end
  end
end
