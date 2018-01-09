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

    it "#selector_parts" do
      expect(described_class.instance_methods).to include(:selector_parts)
    end

    it "#container_nodes" do
      expect(described_class.instance_methods).to include(:container_nodes)
    end

    it "#container_image_registry" do
      expect(described_class.instance_methods).to include(:container_image_registry)
    end
  end
end
