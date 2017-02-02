module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerService do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#container_groups" do
      expect(described_class.instance_methods).to include(:container_groups)
    end

    it "#container_routes" do
      expect(described_class.instance_methods).to include(:container_routes)
    end

    it "#container_service_port_configs" do
      expect(described_class.instance_methods).to include(:container_service_port_configs)
    end

    it "#container_project" do
      expect(described_class.instance_methods).to include(:container_project)
    end

    it "#labels" do
      expect(described_class.instance_methods).to include(:labels)
    end

    it "#selector_parts" do
      expect(described_class.instance_methods).to include(:selector_parts)
    end

    it "#container_nodes" do
      expect(described_class.instance_methods).to include(:container_nodes)
    end

    it "#container_image_registry" do
      expect(described_class.instance_methods).to include(:container_image_registry)
    end

    it "#metrics" do
      expect(described_class.instance_methods).to include(:metrics)
    end

    it "#metric_rollups" do
      expect(described_class.instance_methods).to include(:metric_rollups)
    end
  end
end
