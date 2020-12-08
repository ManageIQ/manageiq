RSpec.describe ArVisibleAttribute do
  # NOTE: ApplicationRecord already included ArVisibleAttribute
  let(:klass) { Class.new(ApplicationRecord) { self.table_name = "vms" } }
  let(:other_klass) { Class.new(ApplicationRecord) { self.table_name = "vms" } }
  let(:child_klass) { Class.new(klass) }

  context ".visible_attribute_names" do
    it "shows regular attributes" do
      expect(klass.visible_attribute_names).to include("type")
    end

    it "shows virtual attributes" do
      klass.virtual_attribute :superb, :string
      expect(klass.visible_attribute_names).to include("superb")
    end

    it "hides hidden virtual attributes" do
      klass.virtual_attribute :superb, :string
      klass.hide_attribute :superb
      expect(klass.visible_attribute_names).not_to include("superb")
    end

    it "hides hidden attributes" do
      klass.hide_attribute :type
      expect(klass.visible_attribute_names).not_to include("type")
    end

    it "only hides for specified class" do
      klass.hide_attribute :type
      expect(other_klass.visible_attribute_names).to include("type")
    end

    context "child class" do
      it "shows regular attributes" do
        expect(child_klass.visible_attribute_names).to include("type")
      end

      it "hides attributes that are hidden in parent class" do
        klass.hide_attribute :type
        expect(child_klass.visible_attribute_names).not_to include("type")
      end

      it "hides virtual attributes that are hidden in the parent class" do
        klass.virtual_attribute :superb, :string
        klass.hide_attribute :superb
        expect(child_klass.visible_attribute_names).not_to include("superb")
      end

      it "hides attributes that are hidden in class and parent class" do
        klass.hide_attribute :type
        child_klass.hide_attribute :name
        expect(child_klass.visible_attribute_names).not_to include("type")
        expect(child_klass.visible_attribute_names).not_to include("name")
      end

      it "hides attribute only for class and below" do
        child_klass.hide_attribute :name
        expect(klass.visible_attribute_names).to include("name")
        expect(child_klass.visible_attribute_names).not_to include("name")
      end
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

    context "child class" do
      it "starts with no hidden attributes" do
        expect(child_klass.hidden_attribute_names).to be_empty
      end

      it "hides attributes that are hidden in parent class" do
        klass.hide_attribute :type
        expect(child_klass.hidden_attribute_names).to include("type")
      end

      it "hides attributes that are hidden in parent class" do
        klass.hide_attribute :type
        child_klass.hide_attribute :name
        expect(child_klass.hidden_attribute_names).to include("type")
        expect(child_klass.hidden_attribute_names).to include("name")
      end
    end
  end
end
