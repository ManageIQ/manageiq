require "spec_helper"

describe DialogFieldImporter do
  let(:dialog_field_importer) { described_class.new }

  describe "#import_field" do
    let(:dialog_field) do
      {
        "type"  => type,
        "name"  => "Something",
        "label" => "Something else"
      }
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
