module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainer do
    let(:container) { FactoryGirl.create(:container) }

    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#container_node" do
      expect(described_class.instance_methods).to include(:container_node)
    end

    it "#container_image" do
      expect(described_class.instance_methods).to include(:container_image)
    end
  end
end
