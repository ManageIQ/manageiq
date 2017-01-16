module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerImageRegistry do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#container_images" do
      expect(described_class.instance_methods).to include(:container_images)
    end

    it "#containers" do
      expect(described_class.instance_methods).to include(:containers)
    end

    it "#container_services" do
      expect(described_class.instance_methods).to include(:container_services)
    end

    it "#container_groups" do
      expect(described_class.instance_methods).to include(:container_groups)
    end
  end
end
