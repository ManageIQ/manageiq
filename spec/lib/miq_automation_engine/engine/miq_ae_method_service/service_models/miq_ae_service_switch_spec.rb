module MiqAeServiceSwitchSpec
  describe MiqAeMethodService::MiqAeServiceSwitch do
    it "#hosts" do
      expect(described_class.instance_methods).to include(:hosts)
    end

    it "#guest_devices" do
      expect(described_class.instance_methods).to include(:guest_devices)
    end

    it "#lans" do
      expect(described_class.instance_methods).to include(:lans)
    end
  end
end
