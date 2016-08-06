module MiqAeServiceConfigurationScriptSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceConfigurationScript do
    it "get the service model class" do
      expect { described_class }.not_to raise_error
    end

    it "#inventory_root_group" do
      expect(described_class.instance_methods).to include(:inventory_root_group)
    end

    it "#manager" do
      expect(described_class.instance_methods).to include(:manager)
    end
  end
end
