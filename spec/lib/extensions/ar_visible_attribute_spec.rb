RSpec.describe ArVisibleAttribute do
  # NOTE: ApplicationRecord already included ArVisibleAttribute
  let(:klass) { Class.new(ApplicationRecord) { self.table_name = "vms" } }
  let(:other_klass) { Class.new(ApplicationRecord) { self.table_name = "vms" } }

  context ".visible_attribute_names" do
    it "shows regular attributes" do
      expect(klass.visible_attribute_names).to include("type")
    end

    it "hides hidden attributes" do
      klass.hide_attribute :type
      expect(klass.visible_attribute_names).not_to include("type")
    end

    it "only hides for specified class" do
      klass.hide_attribute :type
      expect(other_klass.visible_attribute_names).to include("type")
    end
  end

  context ".hidden_attribute_names" do
    it "starts with no hidden attributes" do
      expect(klass.hidden_attribute_names).to be_empty
    end

    it "hides hidden attributes" do
      klass.hide_attribute :type
      expect(klass.hidden_attribute_names).to include("type")
    end

    it "only hides for specified class" do
      klass.hide_attribute :type
      expect(other_klass.hidden_attribute_names).not_to include("type")
    end
  end
end
