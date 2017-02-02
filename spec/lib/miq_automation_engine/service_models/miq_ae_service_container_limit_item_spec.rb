module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerLimitItem do
    it "#container_limit" do
      expect(described_class.instance_methods).to include(:container_limit)
    end
  end
end
