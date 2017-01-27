module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerNode do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#container_groups" do
      expect(described_class.instance_methods).to include(:container_groups)
    end

    it "#container_conditions" do
      expect(described_class.instance_methods).to include(:container_conditions)
    end

    it "#containers" do
      expect(described_class.instance_methods).to include(:containers)
    end

    it "#container_images" do
      expect(described_class.instance_methods).to include(:container_images)
    end

    it "#container_services" do
      expect(described_class.instance_methods).to include(:container_services)
    end

    it "#container_routes" do
      expect(described_class.instance_methods).to include(:container_routes)
    end

    it "#container_replicators" do
      expect(described_class.instance_methods).to include(:container_replicators)
    end

    it "#labels" do
      expect(described_class.instance_methods).to include(:labels)
    end

    it "#computer_system" do
      expect(described_class.instance_methods).to include(:computer_system)
    end

    it "#lives_on" do
      expect(described_class.instance_methods).to include(:lives_on)
    end

    it "#hardware" do
      expect(described_class.instance_methods).to include(:hardware)
    end

    it "#metrics" do
      expect(described_class.instance_methods).to include(:metrics)
    end

    it "#metric_rollups" do
      expect(described_class.instance_methods).to include(:metric_rollups)
    end
  end
end
