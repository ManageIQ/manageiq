module MiqAeServiceServiceLoadBalancerSpec
  describe MiqAeMethodService::MiqAeServiceServiceLoadBalancer do
    let(:lb_template)        { FactoryGirl.create(:load_balancer_template) }
    let(:lb_manager)         { FactoryGirl.create(:ems_amazon).network_manager }
    let(:load_balancer_opts) { {'any_key' => 'any_value'} }
    let(:ae_lb_manager)      { MiqAeMethodService::MiqAeServiceExtManagementSystem.find(lb_manager.id) }
    let(:service_template)   { FactoryGirl.create(:service_template_load_balancer) }
    let(:ss_template)        { MiqAeMethodService::MiqAeServiceServiceTemplate.find(service_template.id) }
    let(:service)            { FactoryGirl.create(:service_load_balancer, :service_template => service_template) }
    let(:service_service)    { MiqAeMethodService::MiqAeServiceService.find(service.id) }

    it "sets and gets load_balancer_manager" do
      service_service.load_balancer_manager = ae_lb_manager
      expect(service.load_balancer_manager).to eq(lb_manager)
      expect(service_service.load_balancer_manager.object_class.name).to eq('ManageIQ::Providers::Amazon::NetworkManager')
    end

    it "sets and gets load_balancer_name" do
      service_service.load_balancer_name = 'load_balancer_name'
      expect(service_service.load_balancer_name).to eq('load_balancer_name')
    end

    it "sets and gets load_balancer_options" do
      service_service.load_balancer_options = load_balancer_opts
      expect(service_service.load_balancer_options).to eq(load_balancer_opts)
    end

    it "sets and gets update_options" do
      service_service.update_options = load_balancer_opts
      expect(service_service.update_options).to eq(load_balancer_opts)
    end
  end
end
