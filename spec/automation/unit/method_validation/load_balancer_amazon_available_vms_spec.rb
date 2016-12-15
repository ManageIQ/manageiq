describe "Available_Vms Method Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  before do
    @ins = "/Cloud/LoadBalancer/Operations/Amazon/Methods/Available_Vms"
  end

  context "workspace has no service template" do
    it "provides only default value to the cloud_network list" do
      ws = MiqAeEngine.instantiate("#{@ins}", user)
      expect(ws.root["values"]).to eq({})
      expect(ws.root["default_value"]).to be_nil
    end
  end

  context "workspace has service template other than load_balancer" do
    let(:service_template) { FactoryGirl.create(:service_template) }

    it "provides only default value to the cloud_network list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      expect(ws.root["values"]).to eq({})
      expect(ws.root["default_value"]).to be_nil
    end
  end

  let(:ems) do
    FactoryGirl.create(:ems_amazon).network_manager
  end

  before :each do
    @vm_1            = FactoryGirl.create(:vm_amazon,
                                          :name                  => 'subnet 1',
                                          :ext_management_system => ems)
    @vm_2            = FactoryGirl.create(:vm_amazon,
                                          :name                  => 'subnet 2',
                                          :ext_management_system => ems)
    @vm_ec2_classic  = FactoryGirl.create(:vm_amazon,
                                          :name                  => 'subnet 2',
                                          :ext_management_system => ems)
    @cloud_network_1 = FactoryGirl.create("cloud_network_amazon".to_sym,
                                          :name                  => "Cloud Network",
                                          :ext_management_system => ems)
    @cloud_network_2 = FactoryGirl.create("cloud_network_amazon".to_sym,
                                          :name                  => "Cloud Network",
                                          :ext_management_system => ems)
    @cloud_subnet    = FactoryGirl.create("cloud_subnet_amazon".to_sym,
                                          :cloud_network         => @cloud_network_1,
                                          :ext_management_system => ems,
                                          :name                  => "Cloud Subnet")
    @network_port_1  = FactoryGirl.create("network_port_amazon".to_sym,
                                          :name                  => "eth0",
                                          :mac_address           => "06:04:25:40:8e:79",
                                          :device                => @vm_1,
                                          :ext_management_system => ems)
    @network_port_2  = FactoryGirl.create("network_port_amazon".to_sym,
                                          :name                  => "eth0",
                                          :mac_address           => "06:04:25:40:8e:79",
                                          :device                => @vm_2,
                                          :ext_management_system => ems)
    FactoryGirl.create(:cloud_subnet_network_port,
                       :cloud_subnet => @cloud_subnet,
                       :network_port => @network_port_1,
                       :address      => "10.10.0.2")
    FactoryGirl.create(:cloud_subnet_network_port,
                       :cloud_subnet => @cloud_subnet,
                       :network_port => @network_port_2,
                       :address      => "10.10.0.2")
  end

  context "workspace has an EC2 classic cloud_network" do
    let(:service_template) do
      FactoryGirl.create(:service_template_load_balancer, :load_balancer_manager => ems)
    end

    let(:service_template_no_ems) do
      FactoryGirl.create(:service_template_load_balancer)
    end

    it "finds all the cloud_networks and populates the list" do
      dialog = "dialog_cloud_network=#{nil}"
      ws     = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}&#{dialog}",
                                       user)
      expect(ws.root["values"]).to eq({})
      expect(ws.root["default_value"]).to be_nil
    end

    it "provides only default value to the cloud_network list if load_balancer manager does not exist" do
      dialog = "dialog_cloud_network=#{nil}"
      ws     = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template_no_ems.id}&#{dialog}",
                                       user)
      expect(ws.root["values"]).to eq({})
      expect(ws.root["default_value"]).to be_nil
    end
  end

  context "workspace has a cloud_network without vms" do
    let(:service_template) do
      FactoryGirl.create(:service_template_load_balancer, :load_balancer_manager => ems)
    end

    let(:service_template_no_ems) do
      FactoryGirl.create(:service_template_load_balancer)
    end

    it "finds all the cloud_networks and populates the list" do
      dialog = "dialog_cloud_network=#{@cloud_network_2.id}"
      ws     = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}&#{dialog}",
                                       user)
      expect(ws.root["values"]).to eq({})
      expect(ws.root["default_value"]).to be_nil
    end

    it "provides only default value to the cloud_network list if load_balancer manager does not exist" do
      dialog = "dialog_cloud_network=#{@cloud_network_2.id}"
      ws     = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template_no_ems.id}&#{dialog}",
                                       user)
      expect(ws.root["values"]).to eq({})
      expect(ws.root["default_value"]).to be_nil
    end
  end

  context "workspace has load_balancer service template" do
    let(:service_template) do
      FactoryGirl.create(:service_template_load_balancer, :load_balancer_manager => ems)
    end

    let(:service_template_no_ems) do
      FactoryGirl.create(:service_template_load_balancer)
    end

    it "finds all the cloud_networks and populates the list" do
      dialog = "dialog_cloud_network=#{@cloud_network_1.id}"
      ws     = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}&#{dialog}", 
                                       user)
      expect(ws.root["values"]).to include(
        @vm_1.id => @vm_1.name,
        @vm_2.id => @vm_2.name
      )
      expect(ws.root["default_value"]).to be_nil
    end

    it "provides only default value to the cloud_network list if load_balancer manager does not exist" do
      dialog = "dialog_cloud_network=#{@cloud_network_1.id}"
      ws     = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template_no_ems.id}&#{dialog}", 
                                      user)
      expect(ws.root["values"]).to eq({})
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
      dialog = "dialog_cloud_network=#{@cloud_network_1.id}"
      ws     = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service.id}&#{dialog}", user)
      expect(ws.root["values"]).to include(
        @vm_1.id => @vm_1.name,
        @vm_2.id => @vm_2.name
      )
      expect(ws.root["default_value"]).to be_nil
    end

    it "provides only default value to the cloud_network list if load_balancer manager does not exist" do
      dialog = "dialog_cloud_network=#{@cloud_network_1.id}"
      ws     = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service_no_ems.id}&#{dialog}", user)
      expect(ws.root["values"]).to eq({})
      expect(ws.root["default_value"]).to be_nil
    end
  end
end
