RSpec.describe DialogFieldCheckBox do
  describe "#checked?" do
    let(:dialog_field) { described_class.new(:value => value) }

    context "when the value is 't'" do
      let(:value) { "t" }

      it "returns true" do
        expect(dialog_field.checked?).to be_truthy
      end
    end

    context "when the value is anything else" do
      let(:value) { "1" }

      it "returns false" do
        expect(dialog_field.checked?).to be_falsey
      end
    end
  end

  describe "#initial_values" do
    let(:dialog_field) { described_class.new }

    it "returns false" do
      expect(dialog_field.initial_values).to be_falsey
    end
  end

  describe "#script_error_values" do
    let(:dialog_field_checkbox) { described_class.new }

    it "returns the script error value" do
      expect(dialog_field_checkbox.script_error_values).to eq("<Script error>")
    end
  end

  describe "#normalize_automate_values" do
    let(:dialog_field) { described_class.new }
    let(:automate_hash) do
      {
        "value"       => value,
        "required"    => true,
        "read_only"   => true,
        "description" => "description"
      }
    end

    shared_examples_for "DialogFieldCheckbox#normalize_automate_values" do
      before do
        dialog_field.normalize_automate_values(automate_hash)
      end

      it "sets the required" do
        expect(dialog_field.required).to be_truthy
      end

      it "sets the read_only" do
        expect(dialog_field.read_only).to be_truthy
      end

      it "sets the description" do
        expect(dialog_field.description).to eq("description")
      end
    end

    context "when the automate hash has a value" do
      let(:value) { '1' }

      it_behaves_like "DialogFieldCheckbox#normalize_automate_values"

      it "returns the value in a string format" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq("1")
      end
    end

    context "when the automate hash does not have a value" do
      let(:value) { nil }

      it_behaves_like "DialogFieldCheckbox#normalize_automate_values"

      it "sets the value" do
        dialog_field.normalize_automate_values(automate_hash)
        expect(dialog_field.value).to eq(nil)
      end

      it "returns the initial values" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq(false)
      end
    end
  end

  describe "#validate_field_data" do
    let(:dialog_field_check_box) do
      described_class.new(:label    => 'dialog_field_check_box',
                          :name     => 'dialog_field_check_box',
                          :required => required,
                          :value    => value)
    end
    let(:dialog_tab)   { double('DialogTab',   :label => 'tab') }
    let(:dialog_group) { double('DialogGroup', :label => 'group') }

    shared_examples_for "DialogFieldCheckBox#validate_field_data that returns nil" do
      it "returns nil" do
        expect(dialog_field_check_box.validate_field_data(dialog_tab, dialog_group)).to be_nil
      end
    end

    context "when required is true" do
      let(:required) { true }

      context "with a true value" do
        let(:value) { "t" }

        it_behaves_like "DialogFieldCheckBox#validate_field_data that returns nil"
      end

      context "with a false value" do
        let(:value) { "f" }

        it "returns error message" do
          expect(dialog_field_check_box.validate_field_data(dialog_tab, dialog_group)).to eq(
            "tab/group/dialog_field_check_box is required"
          )
        end
      end
    end

    context "when required is false" do
      let(:required) { false }

      context "with a true value" do
        let(:value) { "t" }

        it_behaves_like "DialogFieldCheckBox#validate_field_data that returns nil"
      end

      context "with a false value" do
        let(:value) { "f" }

        it_behaves_like "DialogFieldCheckBox#validate_field_data that returns nil"
      end
    end
  end

  describe "#refresh_json_value" do
    let(:dialog_field) { described_class.new(:read_only => true) }

    before do
      allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return("f")
    end

    it "returns the checked value in a hash" do
      expect(dialog_field.refresh_json_value).to eq(:checked => false, :read_only => true, :visible => true)
    end

    it "assigns the processed value to value" do
      dialog_field.refresh_json_value
      expect(dialog_field.value).to eq("f")
    end
  end

  describe "#trigger_automate_value_updates" do
    let(:dialog_field) { described_class.new }

    before do
      allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return("f")
    end

    it "returns the checked value in a hash" do
      expect(dialog_field.trigger_automate_value_updates).to eq("f")
    end
  end
end
