module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerCondition do
    it "#container_entity" do
      expect(described_class.instance_methods).to include(:container_entity)
    end
  end
end
