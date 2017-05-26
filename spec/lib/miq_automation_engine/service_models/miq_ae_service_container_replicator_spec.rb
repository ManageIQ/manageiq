module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerReplicator do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#container_groups" do
      expect(described_class.instance_methods).to include(:container_groups)
    end

    it "#container_project" do
      expect(described_class.instance_methods).to include(:container_project)
    end

    it "#selector_parts" do
      expect(described_class.instance_methods).to include(:selector_parts)
    end

    it "#container_nodes" do
      expect(described_class.instance_methods).to include(:container_nodes)
    end

    it "#metrics" do
      expect(described_class.instance_methods).to include(:metrics)
    end
  end
end
