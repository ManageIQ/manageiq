RSpec.describe DialogFieldTextAreaBox do
  let(:dialog_field) { described_class.new }

  describe "#normalize_automate_values" do
    let(:automate_hash) do
      {
        "data_type"      => "datatype",
        "value"          => value,
        "protected"      => true,
        "description"    => "description",
        "required"       => true,
        "read_only"      => true,
        "validator_rule" => "rule",
        "validator_type" => "regex"
      }
    end

    shared_examples_for "DialogFieldTextBox#normalize_automate_values" do
      before do
        dialog_field.normalize_automate_values(automate_hash)
      end

      it "does not set the data_type" do
        expect(dialog_field.data_type).to be_nil
      end

      it "does not set the protected" do
        expect(dialog_field.protected?).to be_falsey
      end

      it "sets the validator type" do
        expect(dialog_field.validator_type).to eq("regex")
      end

      it "sets the validator rule" do
        expect(dialog_field.validator_rule).to eq("rule")
      end

      it "sets the required" do
        expect(dialog_field.required).to be_truthy
      end

      it "sets the description" do
        expect(dialog_field.description).to eq("description")
      end

      it "sets the read_only" do
        expect(dialog_field.read_only).to be_truthy
      end
    end

    context "when the automate hash does not have a value" do
      let(:value) { nil }

      it_behaves_like "DialogFieldTextBox#normalize_automate_values"

      it "returns the initial values" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq("")
      end
    end

    context "when the automate hash has a value" do
      let(:value) { '123' }

      it_behaves_like "DialogFieldTextBox#normalize_automate_values"

      it "returns the value in string format" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq("123")
      end
    end
  end
end
