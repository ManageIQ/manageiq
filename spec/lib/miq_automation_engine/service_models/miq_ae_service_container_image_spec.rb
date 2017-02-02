module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerImage do
    it "#container_image_registry" do
      expect(described_class.instance_methods).to include(:container_image_registry)
    end

    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#containers" do
      expect(described_class.instance_methods).to include(:containers)
    end

    it "#container_nodes" do
      expect(described_class.instance_methods).to include(:container_nodes)
    end

    it "#container_groups" do
      expect(described_class.instance_methods).to include(:container_groups)
    end

    it "#container_projects" do
      expect(described_class.instance_methods).to include(:container_projects)
    end

    it "#guest_applications" do
      expect(described_class.instance_methods).to include(:guest_applications)
    end

    it "#computer_system" do
      expect(described_class.instance_methods).to include(:computer_system)
    end

    it "#operating_system" do
      expect(described_class.instance_methods).to include(:operating_system)
    end

    it "#openscap_result" do
      expect(described_class.instance_methods).to include(:openscap_result)
    end

    it "#openscap_rule_results" do
      expect(described_class.instance_methods).to include(:openscap_rule_results)
    end

    it "#exposed_ports" do
      expect(described_class.instance_methods).to include(:exposed_ports)
    end

    it "#environment_variables" do
      expect(described_class.instance_methods).to include(:environment_variables)
    end
  end
end
