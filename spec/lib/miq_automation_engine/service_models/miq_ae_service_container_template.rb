module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerTemplate do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#container_template_parameters" do
      expect(described_class.instance_methods).to include(:container_template_parameters)
    end
  end
end
