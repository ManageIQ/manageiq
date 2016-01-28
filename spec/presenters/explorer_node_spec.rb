describe ExplorerNode do
  context "initialize" do
    it "with value '-Unassigned'" do
      node = described_class.new("-Unassigned")
      expect(node).to be_a_kind_of(described_class)
      expect(node.elements).to eq([{:prefix => nil, :class_name => nil, :id => "Unassigned"}])
    end

    it "sets class_name to nil with unknown prefix" do
      node = described_class.new("model-123")
      expect(node).to be_a_kind_of(described_class)
      expect(node.elements).to eq([{:prefix => "model", :class_name => nil, :id => "123"}])
    end

    it "sets class_name properly with known prefix" do
      node = described_class.new("z-123")
      expect(node).to be_a_kind_of(described_class)
      expect(node.elements).to eq([{:prefix => "z", :class_name => "Zone", :id => "123"}])
    end
  end

  context "#zone?" do
    it "returns true with prefix of z" do
      node = described_class.new("z-123")
      expect(node).to be_a_kind_of(described_class)
      expect(node.zone?).to eq(true)
    end

    it "returns false with prefix of non-z" do
      node = described_class.new("x-123")
      expect(node).to be_a_kind_of(described_class)
      expect(node.zone?).to eq(false)
    end
  end
end
