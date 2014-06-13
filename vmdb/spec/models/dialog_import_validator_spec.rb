require "spec_helper"

describe DialogImportValidator do
  let(:dialog_import_validator) { described_class.new }

  describe "#determine_validity" do
    let(:import_file_upload) do
      active_record_instance_double("ImportFileUpload", :uploaded_content => uploaded_content)
    end

    context "when the yaml is completely valid" do
      let(:uploaded_content) do
        [{"dialog_tabs" => [{"dialog_groups" => [{"dialog_fields" => [{"type" => "DialogFieldTextBox"}]}]}]}].to_yaml
      end

      it "does not raise any errors" do
        expect { dialog_import_validator.determine_validity(import_file_upload) }.to_not raise_error
      end
    end

    context "when the yaml is invalid yaml" do
      let(:uploaded_content) { "-\nbad yaml" }

      it "raises a DialogImportValidator::ImportNonYamlError" do
        expect {
          dialog_import_validator.determine_validity(import_file_upload)
        }.to raise_error(DialogImportValidator::ImportNonYamlError)
      end
    end

    context "when the dialog fields type is not one of the DIALOG_FIELD_TYPES" do
      let(:uploaded_content) do
        [{"dialog_tabs" => [{"dialog_groups" => [{"dialog_fields" => [{"type" => field_type}]}]}]}].to_yaml
      end

      context "when the dialog fields type is not nil" do
        let(:field_type) { "test" }

        it "raises a DialogImportValidator::InvalidDialogFieldTypeError" do
          expect {
            dialog_import_validator.determine_validity(import_file_upload)
          }.to raise_error(DialogImportValidator::InvalidDialogFieldTypeError)
        end
      end

      context "when the dialog fields type is nil" do
        let(:field_type) { nil }

        it "does not raise an error" do
          expect { dialog_import_validator.determine_validity(import_file_upload) }.to_not raise_error
        end
      end
    end

    context "when the yaml does not represent dialogs" do
      shared_examples_for "DialogImportValidator#determine_validity parsing non dialog yaml content" do
        it "raises a ParsedNonDialogYamlError" do
          expect {
            dialog_import_validator.determine_validity(import_file_upload)
          }.to raise_error(DialogImportValidator::ParsedNonDialogYamlError)
        end
      end

      context "when the 'dialog' does not have dialog tabs'" do
        let(:uploaded_content) { [{"this is not" => "dialog yaml"}].to_yaml }

        it_behaves_like "DialogImportValidator#determine_validity parsing non dialog yaml content"
      end

      context "when the 'dialog' does not have dialog groups'" do
        let(:uploaded_content) { [{"dialog_tabs" => [{"this is not" => "dialog yaml"}]}].to_yaml }

        it_behaves_like "DialogImportValidator#determine_validity parsing non dialog yaml content"
      end

      context "when the 'dialog' does not have dialog fields'" do
        let(:uploaded_content) do
          [{"dialog_tabs" => [{"dialog_groups" => [{"this is not" => "dialog yaml"}]}]}].to_yaml
        end

        it_behaves_like "DialogImportValidator#determine_validity parsing non dialog yaml content"
      end
    end
  end
end
