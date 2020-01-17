RSpec.describe ManageIQ::Providers::Inflector do
  context "#provider_name" do
    it "returns the name for an instance of a manager" do
      manager = ManageIQ::Providers::Amazon::CloudManager.new
      expect(described_class.provider_name(manager)).to eq('Amazon')
    end

    it "returns the name for an instance of a manager when called on the instance" do
      manager = ManageIQ::Providers::Amazon::CloudManager.new
      expect(manager.provider_name).to eq('Amazon')
    end

    it "returns the name for a class of a manager" do
      manager = ManageIQ::Providers::Amazon::CloudManager
      expect(described_class.provider_name(manager)).to eq('Amazon')
    end

    it "returns the name for an instance of a Vm" do
      vm = ManageIQ::Providers::Amazon::CloudManager::Vm.new
      expect(described_class.provider_name(vm)).to eq('Amazon')
    end

    it "raises an error on not namespaced objects" do
      vm = Vm.new
      expect do
        described_class.provider_name(vm)
      end.to raise_error(ManageIQ::Providers::Inflector::ObjectNotNamespacedError)
    end
  end

  context "#manager_type" do
    it "returns the type for an instance of a manager" do
      manager = ManageIQ::Providers::Amazon::CloudManager.new
      expect(described_class.manager_type(manager)).to eq('Cloud')
    end

    it "returns the type for an instance of a manager when called on the instance" do
      manager = ManageIQ::Providers::Amazon::CloudManager.new
      expect(manager.manager_type).to eq('Cloud')
    end

    it "returns the type for a class of a manager" do
      manager = ManageIQ::Providers::Amazon::CloudManager
      expect(described_class.manager_type(manager)).to eq('Cloud')
    end

    it "returns the type for an instance of a Vm" do
      vm = ManageIQ::Providers::Amazon::CloudManager::Vm.new
      expect(described_class.manager_type(vm)).to eq('Cloud')
    end

    it "raises an error on not namespaced objects" do
      vm = Vm.new
      expect do
        described_class.manager_type(vm)
      end.to raise_error(ManageIQ::Providers::Inflector::ObjectNotNamespacedError)
    end
  end
end
