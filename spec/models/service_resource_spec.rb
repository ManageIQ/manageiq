RSpec.describe ServiceResource do
  it "default values" do
    expect(subject.group_idx).to eq(0)
    expect(subject.scaling_min).to eq(1)
    expect(subject.scaling_max).to eq(-1)
    expect(subject.provision_index).to eq(0)
  end

  context "with a nil resource" do
    it "#resource_name" do
      expect(subject.resource_name).to eq("")
    end

    it "#resource_description" do
      expect(subject.resource_description).to eq("")
    end
  end

  context "with a service as a resource" do
    before do
      @service = FactoryBot.create(:service, :name => "Svc_A", :description => "Test Service")
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
