module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerDefinition do
    it "#container_group" do
      expect(described_class.instance_methods).to include(:container_group)
    end

    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#container_port_configs" do
      expect(described_class.instance_methods).to include(:container_port_configs)
    end

    it "#container_env_vars" do
      expect(described_class.instance_methods).to include(:container_env_vars)
    end

    it "#container" do
      expect(described_class.instance_methods).to include(:container)
    end

    it "#security_context" do
      expect(described_class.instance_methods).to include(:security_context)
    end

    it "#container_image" do
      expect(described_class.instance_methods).to include(:container_image)
    end
  end
end
