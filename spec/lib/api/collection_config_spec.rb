RSpec.describe Api::CollectionConfig do
  describe "#name_for_klass" do
    it "returns the corresponding name for classes managed by the API" do
      expect(subject.name_for_klass(Vm)).to eq(:vms)
    end

    it "returns nil for classes unknown to the API" do
      expect(subject.name_for_klass(String)).to be_nil
    end
  end
end
