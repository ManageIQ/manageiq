RSpec.describe DeprecationMixin do
  # Host.deprecate_attribute :address, :hostname
  context ".visible_attribute_names" do
    it "hides deprecate_attribute columns" do
      expect(Host.visible_attribute_names).not_to include("address")
    end
  end
end
