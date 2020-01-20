RSpec.describe PostponedTranslation do
  context "translate" do
    it "calls Kernel#format" do
      pt = PostponedTranslation.new("Test %s") { "foo" }
      expect(pt.translate).to eq("Test foo")

      pt = PostponedTranslation.new("Test %s%d") { ["foo", 5] }
      expect(pt.translate).to eq("Test foo5")

      pt = PostponedTranslation.new("Test %{bar}") do
             {:bar => "foo"}
           end
      expect(pt.translate).to eq("Test foo")
    end
  end

  context "#to_proc" do
    it "returns a Proc" do
      pt = PostponedTranslation.new("Test %s") { "foo" }
      expect(pt.to_proc).to be_kind_of(Proc)
    end
  end
end
