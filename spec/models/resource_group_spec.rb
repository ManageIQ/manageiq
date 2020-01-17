RSpec.describe ResourceGroup do
  let(:resource_group) do
    FactoryBot.create(
      :resource_group,
      :type    => "ResourceGroup",
      :name    => "foo",
      :ems_ref => "/subscriptions/xxx/resourceGroups/foo"
    )
  end

  context "properties" do
    it "has the expected resource group" do
      expect(resource_group.type).to eql("ResourceGroup")
    end

    it "has the expected name" do
      expect(resource_group.name).to eql("foo")
    end

    it "has the expected ems_ref" do
      expect(resource_group.ems_ref).to eql("/subscriptions/xxx/resourceGroups/foo")
    end
  end

  context "relationships" do
    before do
      @vm       = FactoryBot.create(:vm_google, :template => false, :resource_group => resource_group)
      @template = FactoryBot.create(:template_google, :template => true, :resource_group => resource_group)
      @cloud_network = FactoryBot.create(:cloud_network, :resource_group => resource_group)
      @network_port = FactoryBot.create(:network_port, :resource_group => resource_group)
      @security_group = FactoryBot.create(:security_group, :resource_group => resource_group)
    end

    it "returns the expected results for vms" do
      expect(resource_group.vms).to include(@vm)
      expect(resource_group.vms).to_not include(@template)
    end

    it "returns the expected results for templates" do
      expect(resource_group.templates).to include(@template)
      expect(resource_group.templates).to_not include(@vm)
    end

    it "returns the expected results for vm_or_templates" do
      expect(resource_group.vm_or_templates).to include(@template)
      expect(resource_group.vm_or_templates).to include(@vm)
    end

    it "returns the expected results for cloud_networks" do
      expect(resource_group.cloud_networks).to include(@cloud_network)
    end

    it "returns the expected results for network_ports" do
      expect(resource_group.network_ports).to include(@network_port)
    end

    it "returns the expected results for security_groups" do
      expect(resource_group.security_groups).to include(@security_group)
    end
  end
end
