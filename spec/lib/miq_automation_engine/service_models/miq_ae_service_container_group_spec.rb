module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerGroup do
    it "#containers" do
      expect(described_class.instance_methods).to include(:containers)
    end

    it "#container_definitions" do
      expect(described_class.instance_methods).to include(:container_definitions)
    end

    it "#container_images" do
      expect(described_class.instance_methods).to include(:container_images)
    end

    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#labels" do
      expect(described_class.instance_methods).to include(:labels)
    end

    it "#node_selector_parts" do
      expect(described_class.instance_methods).to include(:node_selector_parts)
    end

    it "#container_node" do
      expect(described_class.instance_methods).to include(:container_node)
    end

    it "#container_services" do
      expect(described_class.instance_methods).to include(:container_services)
    end

    it "#container_replicator" do
      expect(described_class.instance_methods).to include(:container_replicator)
    end

    it "#container_project" do
      expect(described_class.instance_methods).to include(:container_project)
    end

    it "#container_build_pod" do
      expect(described_class.instance_methods).to include(:container_build_pod)
    end

    it "#container_volumes" do
      expect(described_class.instance_methods).to include(:container_volumes)
    end

    it "#metrics" do
      expect(described_class.instance_methods).to include(:metrics)
    end

    it "#metric_rollups" do
      expect(described_class.instance_methods).to include(:metric_rollups)
    end

    it "#vim_performance_states" do
      expect(described_class.instance_methods).to include(:vim_performance_states)
    end
  end
end
