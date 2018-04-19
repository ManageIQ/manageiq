describe ServiceResource do
  it "default values" do
    expect(subject.group_idx).to eq(0)
    expect(subject.scaling_min).to eq(1)
    expect(subject.scaling_max).to eq(-1)
    expect(subject.provision_index).to eq(0)
  end

  context "#resource_name" do
    it "handles nil resource" do
      expect(ServiceResource.new.resource_name).to eq("")
    end

    it "handles resource" do
      expect(ServiceResource.new(:resource => Vm.new(:name => "vm name")).resource_name).to eq("vm name")
    end

    it "handles nameless resource" do
      # resource is an object without a name attribute
      expect(ServiceResource.new(:resource => TimeProfile.new).resource_name).to eq("")
    end
  end

  context "#resource_description" do
    it "handles nil resource" do
      expect(ServiceResource.new.resource_description).to eq("")
    end

    it "handles resource" do
      resource = Classification.new(:description => "the description")
      expect(ServiceResource.new(:resource => resource).resource_description).to eq("the description")
    end

    it "handles nameless resource" do
      # resource is an object without a name attribute
      expect(ServiceResource.new(:resource => Vm.new).resource_description).to eq("")
    end
  end

  context "with a service as a resource" do
    before do
      @service = FactoryGirl.create(:service, :name => "Svc_A", :description => "Test Service")
      subject.resource = @service
    end

    it "#resource_name" do
      expect(subject.resource_name).to eq(@service.name)
    end

    it "#resource_description" do
      expect(subject.resource_description).to eq(@service.description)
    end
  end
end
