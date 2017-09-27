describe DialogFieldAssociationValidator do
  let(:dialog_field_association_validator) { described_class.new }

  describe "circular_references" do
    context "when the associations are blank" do
      let(:associations) { {} }

      it "returns false" do
        expect(dialog_field_association_validator.circular_references(associations)).to eq(false)
      end
    end

    context "when the associations are not blank" do
      context "when there are no circular references" do
        it "returns false" do
          expect(dialog_field_association_validator.circular_references("foo" => ["baz"])).to eq(false)
          expect(dialog_field_association_validator.circular_references("foo" => %w(foo2 foo4), "foo2" => ["foo3"], "foo3" => ["foo4"])).to eq(false)
        end
      end

      context "when there are circular references" do
        it "returns true on the trivial case" do
          expect(dialog_field_association_validator.circular_references("foo" => ["baz"], "baz" => ["foo"])).to eq(%w(baz foo))
        end

        it "returns true on the non-trivial case" do
          expect(dialog_field_association_validator.circular_references("foo" => %w(foo2 foo4), "foo2" => ["foo3"], "foo3" => %w(foo5 foo4), "foo5" => ["foo2"])).to eq(%w(foo2 foo3))
        end

        it "returns true on the non-trivial case" do
          expect(dialog_field_association_validator.circular_references("foo" => %w(foo2 foo4), "foo2" => ["foo3"], "foo4" => ["foo"])).to eq(%w(foo4 foo))
        end
      end
    end
  end
end
