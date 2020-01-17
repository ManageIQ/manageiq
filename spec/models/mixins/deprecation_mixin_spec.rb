RSpec.describe DeprecationMixin do
  # Host.deprecate_attribute :address, :hostname
  context ".arel_attribute" do
    it "works for deprecate_attribute columns" do
      expect(Host.attribute_supported_by_sql?(:address)).to eq(true)
      expect(Host.arel_attribute(:address)).to_not be_nil
      expect(Host.arel_attribute(:address).name).to eq("hostname") # typically this is a symbol. not perfect but it works
    end
  end
end
