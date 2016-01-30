describe "Available_Flavors Method Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:default_desc) { "<None>" }
  before do
    @ins = "/Cloud/Orchestration/Operations/Methods/Available_Flavors"
  end

  context "workspace has no service template" do
    it "provides only default value to the flavor list" do
      ws = MiqAeEngine.instantiate("#{@ins}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
      expect(ws.root["default_value"]).to be_nil
    end
  end

  context "workspace has service template other than orchestration" do
    let(:service_template) { FactoryGirl.create(:service_template) }

    it "provides only default value to the flavor list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
      expect(ws.root["default_value"]).to be_nil
    end
  end

  let(:ems) do
    @flavor1 = FactoryGirl.create(:flavor, :name => 'flavor1')
    @flavor2 = FactoryGirl.create(:flavor, :name => 'flavor2')
    FactoryGirl.create(:ems_openstack, :flavors => [@flavor1, @flavor2])
  end

  context "workspace has orchestration service template" do
    let(:service_template) do
      FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
    end

    let(:service_template_no_ems) do
      FactoryGirl.create(:service_template_orchestration)
    end

    it "finds all the flavors and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      expect(ws.root["values"]).to include(
        nil           => "<Choose>",
        @flavor1.name => @flavor1.name,
        @flavor2.name => @flavor2.name
      )
      expect(ws.root["default_value"]).to be_nil
    end

    it "provides only default value to the flavor list if orchestration manager does not exist" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template_no_ems.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
      expect(ws.root["default_value"]).to be_nil
    end
  end

  context "workspace has orchestration service" do
    let(:service) do
      FactoryGirl.create(:service_orchestration, :orchestration_manager => ems)
    end

    let(:service_no_ems) do
      FactoryGirl.create(:service_orchestration)
    end

    it "finds all the flavors and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service.id}", user)
      expect(ws.root["values"]).to include(
        nil           => "<Choose>",
        @flavor1.name => @flavor1.name,
        @flavor2.name => @flavor2.name
      )
      expect(ws.root["default_value"]).to be_nil
    end

    it "provides only default value to the flavor list if orchestration manager does not exist" do
      ws = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service_no_ems.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
      expect(ws.root["default_value"]).to be_nil
    end
  end
end
