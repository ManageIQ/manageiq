describe "Available_Availability_Zones Method Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:default_desc) { "<select>" }
  before do
    @ins = "/Cloud/Orchestration/Operations/Methods/Available_Availability_Zones"
  end

  context "workspace has no service template" do
    it "provides only the no availability zones info" do
      ws = MiqAeEngine.instantiate(@ins.to_s, user)
      expect(ws.root["values"]).to eq(nil => default_desc)
    end
  end

  context "workspace has service template other than orchestration" do
    let(:service_template) { FactoryGirl.create(:service_template) }

    it "provides only the no availability zones info" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
    end
  end

  let(:ems) do
    @az1 = FactoryGirl.create(:availability_zone, :ems_ref => "ref1")
    @az2 = FactoryGirl.create(:availability_zone, :ems_ref => "ref2")
    FactoryGirl.create(:ems_vmware_cloud, :availability_zones => [@az1, @az2])
  end

  context "workspace has orchestration service template" do
    let(:service_template) do
      FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
    end

    let(:service_template_no_ems) do
      FactoryGirl.create(:service_template_orchestration)
    end

    it "finds all the availability zones and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      expect(ws.root["values"]).to include(
        nil          => default_desc,
        @az1.ems_ref => @az1.name,
        @az2.ems_ref => @az2.name
      )
    end

    it "provides only default value to the availability zones list if orchestration manager does not exist" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template_no_ems.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
    end
  end

  context "workspace has orchestration service" do
    let(:service) do
      FactoryGirl.create(:service_orchestration, :orchestration_manager => ems)
    end

    let(:service_no_ems) do
      FactoryGirl.create(:service_orchestration)
    end

    it "finds all the availability zones and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service.id}", user)
      expect(ws.root["values"]).to include(
        nil          => default_desc,
        @az1.ems_ref => @az1.name,
        @az2.ems_ref => @az2.name
      )
    end

    it "provides only default value to the availability zones list if orchestration manager does not exist" do
      ws = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service_no_ems.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
    end
  end
end
