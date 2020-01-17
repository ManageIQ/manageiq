RSpec.describe DialogFieldAssociationValidator do
  let(:dialog_field_association_validator) { described_class.new }

  describe "circular_references" do
    context "when there are no circular references" do
      let(:associations) { {"e" => ["c"], "c" => ["a", "d"], "d" => ["a"]} }
      let(:trivial_associations) { {"a" => ["b"]} }

      it "doesn't blow up and returns nil" do
      	expect(dialog_field_association_validator.check_for_circular_references({"a" => []} , [])).to eq(nil)
        expect(dialog_field_association_validator.check_for_circular_references(trivial_associations, "a")).to eq(nil)
        expect(dialog_field_association_validator.check_for_circular_references(associations, "e")).to eq(nil)
        expect(dialog_field_association_validator.check_for_circular_references(associations, "c")).to eq(nil)
        expect(dialog_field_association_validator.check_for_circular_references(associations, "d")).to eq(nil)
      end
    end

    context "when there are circular references" do
      let(:trivial_associations) { {"a" => ["b"], "b" => ["a"]} }
      let(:associations) { {"a" => %w(b d), "b" => ["c"], "c" => %w(e d), "e" => ["b"]} }
      let(:associations1) { {"a" => %w(b d), "b" => ["c"], "d" => ["a"]} }

      it "raises circular reference error and returns problematic fields" do
        expect { dialog_field_association_validator.check_for_circular_references(trivial_associations, "a") }.to raise_error(DialogFieldAssociationValidator::DialogFieldAssociationCircularReferenceError, 'a already exists in ["a", "b"]')
        expect { dialog_field_association_validator.check_for_circular_references(trivial_associations, "b") }.to raise_error(DialogFieldAssociationValidator::DialogFieldAssociationCircularReferenceError, 'b already exists in ["b", "a"]')
        expect { dialog_field_association_validator.check_for_circular_references(associations, 'a') }.to raise_error(DialogFieldAssociationValidator::DialogFieldAssociationCircularReferenceError, 'b already exists in ["a", "b", "c", "e"]')
        expect { dialog_field_association_validator.check_for_circular_references(associations1, "a") }.to raise_error(DialogFieldAssociationValidator::DialogFieldAssociationCircularReferenceError, 'a already exists in ["a", "d"]')
        expect(dialog_field_association_validator.check_for_circular_references(associations1, "b")).to eq(nil)
      end
    end
  end
end
