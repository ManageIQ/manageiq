require "spec_helper"

describe DialogFieldTextAreaBox do
  let(:dialog_field) { described_class.new }

  describe "#normalize_automate_values" do
    let(:automate_hash) do
      {
        "data_type"      => "datatype",
        "default_value"  => default_value,
        "protected"      => true,
        "required"       => true,
        "validator_rule" => "rule",
        "validator_type" => "regex"
      }
    end

    shared_examples_for "DialogFieldTextBox#normalize_automate_values" do
      before do
        dialog_field.normalize_automate_values(automate_hash)
      end

      it "does not set the protected" do
        expect(dialog_field.protected?).to be_false
      end

      it "does not set the validator type" do
        expect(dialog_field.validator_type).to be_nil
      end

      it "does not set the validator rule" do
        expect(dialog_field.validator_rule).to be_nil
      end

      it "sets the required" do
        expect(dialog_field.required).to eq(true)
      end
    end

    context "when the automate hash does not have a default value" do
      let(:default_value) { nil }

      it_behaves_like "DialogFieldTextBox#normalize_automate_values"

      it "sets the default_value" do
        dialog_field.normalize_automate_values(automate_hash)
        expect(dialog_field.default_value).to eq(nil)
      end

      it "returns the initial values" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq("<None>")
      end
    end

    context "when the automate hash has a default value" do
      let(:default_value) { '123' }

      it_behaves_like "DialogFieldTextBox#normalize_automate_values"

      it "sets the default_value" do
        dialog_field.normalize_automate_values(automate_hash)
        expect(dialog_field.default_value).to eq('123')
      end

      it "returns the default value in string format" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq("123")
      end
    end
  end
end
