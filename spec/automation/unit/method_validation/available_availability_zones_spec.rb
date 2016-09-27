describe "Available_Availability_Zones Method Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:default_desc_none) { "<none>" }
  let(:default_desc_multiple) { "<select>" }
  before do
    @ins = "/Cloud/Orchestration/Operations/Methods/Available_Availability_Zones"
  end

  context "workspace has no service template" do
    it "provides only the no availability zones info" do
      ws = MiqAeEngine.instantiate(@ins.to_s, user)
      expect(ws.root["values"]).to eq(nil => default_desc_none)
      expect(ws.root["default_value"]).to eq(nil)
    end
  end

  context "workspace has service template other than orchestration" do
    let(:service_template) { FactoryGirl.create(:service_template) }

    it "provides only the no availability zones info" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc_none)
      expect(ws.root["default_value"]).to eq(nil)
    end
  end

  let(:ems_with_single_az) do
    @az1 = FactoryGirl.create(:availability_zone, :ems_ref => "ref1")
    FactoryGirl.create(:ems_vmware_cloud, :availability_zones => [@az1])
  end

  let(:ems) do
    @az2 = FactoryGirl.create(:availability_zone, :ems_ref => "ref1")
    @az3 = FactoryGirl.create(:availability_zone, :ems_ref => "ref2")
    FactoryGirl.create(:ems_vmware_cloud, :availability_zones => [@az2, @az3])
  end

  context "workspace has orchestration service template" do
    let(:service_template_single_az) do
      FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems_with_single_az)
    end

    let(:service_template) do
      FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
    end

    let(:service_template_no_ems) do
      FactoryGirl.create(:service_template_orchestration)
    end

    it "finds a single availabilty zone and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template_single_az.id}", user)
      expect(ws.root["values"]).to include(
        @az1.ems_ref => @az1.name,
      )
      expect(ws.root["default_value"]).to eq(@az1.ems_ref)
    end

    it "finds all the availability zones and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      expect(ws.root["values"]).to include(
        nil          => default_desc_multiple,
        @az2.ems_ref => @az2.name,
        @az3.ems_ref => @az3.name
      )
      expect(ws.root["default_value"]).to eq(nil)
    end

    it "provides only default value to the availability zones list if orchestration manager does not exist" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template_no_ems.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc_none)
      expect(ws.root["default_value"]).to eq(nil)
    end
  end

  context "workspace has orchestration service" do
    let(:service_single_az) do
      FactoryGirl.create(:service_orchestration, :orchestration_manager => ems_with_single_az)
    end

    let(:service) do
      FactoryGirl.create(:service_orchestration, :orchestration_manager => ems)
    end

    let(:service_no_ems) do
      FactoryGirl.create(:service_orchestration)
    end

    it "finds a single availabilty zone and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service_single_az.id}", user)
      expect(ws.root["values"]).to include(
        @az1.ems_ref => @az1.name,
      )
      expect(ws.root["default_value"]).to eq(@az1.ems_ref)
    end

    it "finds all the availability zones and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service.id}", user)
      expect(ws.root["values"]).to include(
        nil          => default_desc_multiple,
        @az2.ems_ref => @az2.name,
        @az3.ems_ref => @az3.name
      )
      expect(ws.root["default_value"]).to eq(nil)
    end

    it "provides only default value to the availability zones list if orchestration manager does not exist" do
      ws = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service_no_ems.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc_none)
      expect(ws.root["default_value"]).to eq(nil)
    end
  end
end
