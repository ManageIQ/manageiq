describe "Available_SecurityGroups Method Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  before do
    @ins = "/Cloud/LoadBalancer/Operations/Amazon/Methods/Available_SecurityGroups"
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
    @cloud_network_1  = FactoryGirl.create(:cloud_network_amazon,
                                           :name                  => 'net 1',
                                           :ext_management_system => ems)
    @cloud_network_2  = FactoryGirl.create(:cloud_network_amazon,
                                           :name                  => 'net 2',
                                           :ext_management_system => ems)
    @security_group_1 = FactoryGirl.create(:security_group_amazon,
                                           :name                  => 'subnet 1',
                                           :cloud_network         => @cloud_network_1,
                                           :ext_management_system => ems)
    @security_group_2 = FactoryGirl.create(:security_group_amazon,
                                           :name                  => 'subnet 2',
                                           :cloud_network         => @cloud_network_1,
                                           :ext_management_system => ems)
    @sg_ec2_classic   = FactoryGirl.create(:security_group_amazon,
                                           :name                  => 'subnet 2',
                                           :cloud_network         => nil,
                                           :ext_management_system => ems)
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

  context "workspace has a cloud_network without security_groups" do
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
        @security_group_1.id => @security_group_1.name,
        @security_group_2.id => @security_group_2.name
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
        @security_group_1.id => @security_group_1.name,
        @security_group_2.id => @security_group_2.name
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
