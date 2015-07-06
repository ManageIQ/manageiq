require "spec_helper"

describe DialogFieldImporter do
  let(:dialog_field_importer) { described_class.new }

  describe "#import_field" do
    let(:dialog_field) do
      {
        "type"            => type,
        "name"            => "Something",
        "label"           => "Something else",
        "resource_action" => resource_action
      }
    end

    let(:resource_action) do
      {
        "ae_namespace" => "Customer/Sample",
        "ae_class"     => "Methods",
        "ae_instance"  => "Testing"
      }
    end

    context "when the type of the dialog field is an old DialogFieldDynamicList" do
      let(:type) { "DialogFieldDynamicList" }

      before do
        @result = dialog_field_importer.import_field(dialog_field)
      end

      it "creates a DialogFieldDropDownList with the correct name" do
        expect(DialogFieldDropDownList.first.name).to eq("Something")
      end

      it "creates a DialogFieldDropDownList with the correct label" do
        expect(DialogFieldDropDownList.first.label).to eq("Something else")
      end

      it "creates a DialogFieldDropDownList with dynamic true" do
        expect(DialogFieldDropDownList.first.dynamic).to be_true
      end

      it "creates a ResourceAction with the given attributes" do
        expect(DialogFieldDropDownList.first.resource_action.fqname).to eq("/Customer/Sample/Methods/Testing")
      end

      it "returns the created object" do
        expect(@result).to eq(DialogFieldDropDownList.first)
      end
    end

    context "when the type of the dialog field is included in DIALOG_FIELD_TYPES" do
      let(:type) { "DialogFieldTextBox" }

      it "creates a DialogFieldTextBox with the correct name" do
        dialog_field_importer.import_field(dialog_field)
        DialogFieldTextBox.first.name.should == "Something"
      end

      it "creates a DialogFieldTextBox with the correct label" do
        dialog_field_importer.import_field(dialog_field)
        DialogFieldTextBox.first.label.should == "Something else"
      end

      it "creates a ResourceAction with the given attributes" do
        dialog_field_importer.import_field(dialog_field)
        expect(DialogFieldTextBox.first.resource_action.fqname).to eq("/Customer/Sample/Methods/Testing")
      end

      it "returns the created object of that type" do
        result = dialog_field_importer.import_field(dialog_field)
        result.should == DialogFieldTextBox.first
      end
    end

    context "when the type of the dialog field is nil" do
      let(:type) { nil }

      it "creates a DialogField with the correct name" do
        dialog_field_importer.import_field(dialog_field)
        DialogField.first.name.should == "Something"
      end

      it "creates a DialogField with the correct label" do
        dialog_field_importer.import_field(dialog_field)
        DialogField.first.label.should == "Something else"
      end

      it "returns the created DialogField object" do
        result = dialog_field_importer.import_field(dialog_field)
        result.should == DialogField.first
      end
    end

    context "when the type of the dialog field is not included in DIALOG_FIELD_TYPES and not nil" do
      let(:type) { "potato" }

      it "raises an InvalidDialogFieldTypeError" do
        expect {
          dialog_field_importer.import_field(dialog_field)
        }.to raise_error(DialogFieldImporter::InvalidDialogFieldTypeError)
      end
    end
  end
end
