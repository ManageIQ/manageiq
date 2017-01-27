module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerRoute do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#container_project" do
      expect(described_class.instance_methods).to include(:container_project)
    end

    it "#container_service" do
      expect(described_class.instance_methods).to include(:container_service)
    end

    it "#container_nodes" do
      expect(described_class.instance_methods).to include(:container_nodes)
    end

    it "#container_groups" do
      expect(described_class.instance_methods).to include(:container_groups)
    end

    it "#labels" do
      expect(described_class.instance_methods).to include(:labels)
    end
  end
end
