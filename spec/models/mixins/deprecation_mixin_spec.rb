RSpec.describe DeprecationMixin do
  # Host.deprecate_attribute :address, :hostname
  context ".arel_table" do
    # this is defining an alias
    # it is not typical for aliases to work through arel_table
    # may need to get rid of this in the future
    it "works for deprecate_attribute columns" do
      expect(Host.attribute_supported_by_sql?(:address)).to eq(true)
      expect(Host.arel_table[:address]).to_not be_nil
      expect(Host.arel_table[:address].name).to eq("hostname") # typically this is a symbol. not perfect but it works
    end
  end

  # Host.deprecate_attribute :address, :hostname
  context ".visible_attribute_names" do
    it "hides deprecate_attribute columns" do
      expect(Host.visible_attribute_names).not_to include("address")
    end
  end
end
