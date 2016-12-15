describe "Available_CloudNetworks Method Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:default_desc) { "EC2-classic" }
  before do
    @ins = "/Cloud/LoadBalancer/Operations/Amazon/Methods/Available_CloudNetworks"
  end

  context "workspace has no service template" do
    it "provides only default value to the cloud_network list" do
      ws = MiqAeEngine.instantiate("#{@ins}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
      expect(ws.root["default_value"]).to be_nil
    end
  end

  context "workspace has service template other than load_balancer" do
    let(:service_template) { FactoryGirl.create(:service_template) }

    it "provides only default value to the cloud_network list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
      expect(ws.root["default_value"]).to be_nil
    end
  end

  let(:ems) do
    @ems_amazon = FactoryGirl.create(:ems_amazon).network_manager

    @cloud_network_1 = FactoryGirl.create(:cloud_network_amazon,
                                          :name                  => 'net 1',
                                          :ext_management_system => @ems_amazon)
    @cloud_network_2 = FactoryGirl.create(:cloud_network_amazon,
                                          :name                  => 'net 2',
                                          :ext_management_system => @ems_amazon)
    @ems_amazon
  end

  context "workspace has load_balancer service template" do
    let(:service_template) do
      FactoryGirl.create(:service_template_load_balancer, :load_balancer_manager => ems)
    end

    let(:service_template_no_ems) do
      FactoryGirl.create(:service_template_load_balancer)
    end

    it "finds all the cloud_networks and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      expect(ws.root["values"]).to include(
        nil                 => default_desc,
        @cloud_network_1.id => @cloud_network_1.name,
        @cloud_network_2.id => @cloud_network_2.name
      )
      expect(ws.root["default_value"]).to be_nil
    end

    it "provides only default value to the cloud_network list if load_balancer manager does not exist" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template_no_ems.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
      expect(ws.root["default_value"]).to be_nil
    end
  end

  context "workspace has load_balancer service" do
    let(:service) do
      FactoryGirl.create(:service_load_balancer, :load_balancer_manager => ems)
    end

    let(:service_no_ems) do
      FactoryGirl.create(:service_load_balancer)
    end

    it "finds all the cloud_networks and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service.id}", user)
      expect(ws.root["values"]).to include(
        nil                 => default_desc,
        @cloud_network_1.id => @cloud_network_1.name,
        @cloud_network_2.id => @cloud_network_2.name
      )
      expect(ws.root["default_value"]).to be_nil
    end

    it "provides only default value to the cloud_network list if load_balancer manager does not exist" do
      ws = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service_no_ems.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
      expect(ws.root["default_value"]).to be_nil
    end
  end
end
