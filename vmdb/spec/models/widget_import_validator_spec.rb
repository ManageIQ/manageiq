require "spec_helper"

describe WidgetImportValidator do
  let(:widget_import_validator) { described_class.new }

  describe "#determine_validity" do
    let(:import_file_upload) do
      active_record_instance_double("ImportFileUpload", :uploaded_content => uploaded_content)
    end

    context "when the yaml is valid" do
      context "when the yaml contains only widgets" do
        let(:uploaded_content) { [{"MiqWidget" => {}}, {"MiqWidget" => {}}].to_yaml }

        it "does not raise any errors" do
          expect { widget_import_validator.determine_validity(import_file_upload) }.to_not raise_error
        end
      end

      context "when the yaml contains stuff other than widgets" do
        let(:uploaded_content) { [{"test" => "garbage"}, {"MiqWidget" => {}}].to_yaml }

        it "raises a WidgetImportValidator::InvalidWidgetYamlError" do
          expect {
            widget_import_validator.determine_validity(import_file_upload)
          }.to raise_error(WidgetImportValidator::InvalidWidgetYamlError)
        end
      end

      context "when the yaml has no widgets" do
        let(:uploaded_content) { [{}].to_yaml }

        it "raises a WidgetImportValidator::InvalidWidgetYamlError" do
          expect {
            widget_import_validator.determine_validity(import_file_upload)
          }.to raise_error(WidgetImportValidator::InvalidWidgetYamlError)
        end
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
