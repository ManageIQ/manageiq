module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerProject do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#container_groups" do
      expect(described_class.instance_methods).to include(:container_groups)
    end
  end
end
