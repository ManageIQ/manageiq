RSpec.describe Api::CollectionConfig do
  describe "#name_for_klass" do
    it "returns the corresponding name for classes managed by the API" do
      expect(subject.name_for_klass(Vm)).to eq(:vms)
    end

    it "returns nil for classes unknown to the API" do
      expect(subject.name_for_klass(String)).to be_nil
    end
  end

  describe "#name_for_subklass" do
    it "returns the collection name for classes declared by the API" do
      expect(subject.name_for_subklass(Vm)).to eq(:vms)
    end

    it "returns the collection name for classes that are accessible via collection_class" do
      expect(subject.name_for_subklass(ManageIQ::Providers::Vmware::InfraManager::Vm)).to eq(:vms)
    end

    it "returns nil for classes unknown to the API" do
      expect(subject.name_for_subklass(String)).to be_nil
    end
  end
end
