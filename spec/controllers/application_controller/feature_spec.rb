describe ApplicationController do
  context "Feature" do
    it "#new_with_hash creates a Struct" do
      expect(described_class::Feature.new_with_hash(:name => "whatever")).to be_a_kind_of(Struct)
    end

    it "#autocomplete doesn't replace stuff" do
      feature = described_class::Feature.new_with_hash(:name => "foo", :accord_name => "bar", :tree_name => "quux", :container => "frob")
      expect(feature.accord_name).to eq("bar")
      expect(feature.tree_name).to eq("quux")
      expect(feature.container).to eq("frob")
    end

    it "#autocomplete does set missing stuff" do
      feature = described_class::Feature.new_with_hash(:name => "foo")
      expect(feature.accord_name).to eq("foo")
      expect(feature.tree_name).to eq(:foo_tree)
      expect(feature.container).to eq("foo_accord")
    end
  end
end
