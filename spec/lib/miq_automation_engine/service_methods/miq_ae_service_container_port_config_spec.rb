module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerPortConfig do
    it "#container_definition" do
      expect(described_class.instance_methods).to include(:container_definition)
    end
  end
end
