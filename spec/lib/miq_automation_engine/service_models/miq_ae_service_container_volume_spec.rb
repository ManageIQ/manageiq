module MiqAeServiceContainerSpec
  describe MiqAeMethodService::MiqAeServiceContainerVolume do
    it "#parent" do
      expect(described_class.instance_methods).to include(:parent)
    end

    it "#persistent_volume_claim" do
      expect(described_class.instance_methods).to include(:persistent_volume_claim)
    end
  end
end
