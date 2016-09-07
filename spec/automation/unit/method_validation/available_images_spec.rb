describe "Available_Images Method Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:default_desc) { "<None>" }
  before do
    @ins = "/Cloud/Orchestration/Operations/Methods/Available_Images"
  end

  context "workspace has no service template" do
    it "provides only default value to the image list" do
      ws = MiqAeEngine.instantiate(@ins.to_s, user)
      expect(ws.root["values"]).to eq(nil => default_desc)
      expect(ws.root["default_value"]).to be_nil
    end
  end

  context "workspace has service template other than orchestration" do
    let(:service_template) { FactoryGirl.create(:service_template) }

    it "provides only default value to the image list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
      expect(ws.root["default_value"]).to be_nil
    end
  end

  context "workspace has orchestration service template" do
    let(:service_template) do
      hw1 = FactoryGirl.create(:hardware, :guest_os => 'windows')
      @img1 = FactoryGirl.create(:template_openstack, :uid_ems => 'uid1', :hardware => hw1)

      hw2 = FactoryGirl.create(:hardware, :guest_os => 'linux')
      @img2 = FactoryGirl.create(:template_openstack, :uid_ems => 'uid2', :hardware => hw2)

      ems = FactoryGirl.create(:ems_openstack, :miq_templates => [@img1, @img2])
      FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
    end

    let(:service_template_one_img) do
      @img1 = FactoryGirl.create(:template_openstack, :uid_ems => 'uid1')
      ems = FactoryGirl.create(:ems_openstack, :miq_templates => [@img1])
      FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
    end

    let(:service_template_no_ems) do
      FactoryGirl.create(:service_template_orchestration)
    end

    it "finds all the images and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      expect(ws.root["values"]).to include(
        nil           => "<Choose>",
        @img1.uid_ems => "windows | #{@img1.name}",
        @img2.uid_ems => "linux | #{@img2.name}"
      )
      expect(ws.root["default_value"]).to be_nil
    end

    it "finds the only image and set it as the only item in the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template_one_img.id}", user)
      expect(ws.root["values"]).to include(
        @img1.uid_ems => "unknown | #{@img1.name}"
      )
      expect(ws.root["default_value"]).to eq(@img1.uid_ems)
    end

    it "provides only default value to the image list if orchestration manager does not exist" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template_no_ems.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
      expect(ws.root["default_value"]).to be_nil
    end
  end

  context "workspace has orchestration service" do
    let(:service) do
      hw1 = FactoryGirl.create(:hardware, :guest_os => 'windows')
      @img1 = FactoryGirl.create(:template_openstack, :uid_ems => 'uid1', :hardware => hw1)

      hw2 = FactoryGirl.create(:hardware, :guest_os => 'linux')
      @img2 = FactoryGirl.create(:template_openstack, :uid_ems => 'uid2', :hardware => hw2)

      ems = FactoryGirl.create(:ems_openstack, :miq_templates => [@img1, @img2])
      FactoryGirl.create(:service_orchestration, :orchestration_manager => ems)
    end

    let(:service_one_img) do
      @img1 = FactoryGirl.create(:template_openstack, :uid_ems => 'uid1')
      ems = FactoryGirl.create(:ems_openstack, :miq_templates => [@img1])
      FactoryGirl.create(:service_orchestration, :orchestration_manager => ems)
    end

    let(:service_no_ems) do
      FactoryGirl.create(:service_orchestration)
    end

    it "finds all the images and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service.id}", user)
      expect(ws.root["values"]).to include(
        nil           => "<Choose>",
        @img1.uid_ems => "windows | #{@img1.name}",
        @img2.uid_ems => "linux | #{@img2.name}"
      )
      expect(ws.root["default_value"]).to be_nil
    end

    it "finds the only image and set it as the only item in the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service_one_img.id}", user)
      expect(ws.root["values"]).to include(
        @img1.uid_ems => "unknown | #{@img1.name}"
      )
      expect(ws.root["default_value"]).to eq(@img1.uid_ems)
    end

    it "provides only default value to the image list if orchestration manager does not exist" do
      ws = MiqAeEngine.instantiate("#{@ins}?Service::service=#{service_no_ems.id}", user)
      expect(ws.root["values"]).to eq(nil => default_desc)
      expect(ws.root["default_value"]).to be_nil
    end
  end
end
