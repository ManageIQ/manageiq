require "spec_helper"

describe WidgetImportValidator do
  let(:widget_import_validator) { described_class.new }

  describe "#determine_validity" do
    let(:import_file_upload) do
      active_record_instance_double("ImportFileUpload", :uploaded_content => uploaded_content)
    end

    context "when the yaml is valid" do
      let(:uploaded_content) { [{}].to_yaml }

      it "does not raise any errors" do
        expect { widget_import_validator.determine_validity(import_file_upload) }.to_not raise_error
      end
    end

    context "when the yaml is invalid yaml" do
      let(:uploaded_content) { "-\nbad yaml" }

      it "raises a WidgetImportValidator::NonYamlError" do
        expect {
          widget_import_validator.determine_validity(import_file_upload)
        }.to raise_error(WidgetImportValidator::NonYamlError)
      end
    end
  end
end
