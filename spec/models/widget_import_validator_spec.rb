RSpec.describe WidgetImportValidator do
  let(:widget_import_validator) { described_class.new }

  describe "#determine_validity" do
    let(:import_file_upload) do
      double("ImportFileUpload", :uploaded_content => uploaded_content)
    end

    context "when the yaml is valid" do
      context "when the yaml contains only widgets" do
        let(:uploaded_content) { [{"MiqWidget" => {}}, {"MiqWidget" => {}}].to_yaml }

        it "does not raise any errors" do
          expect { widget_import_validator.determine_validity(import_file_upload) }.to_not raise_error
        end
      end

      context "when the yaml contains stuff other than widgets" do
        let(:uploaded_content) { [{:test123 => 123}, {"MiqWidget" => {}}].to_yaml }

        it "raises a WidgetImportValidator::InvalidWidgetYamlError" do
          expect do
            widget_import_validator.determine_validity(import_file_upload)
          end.to raise_error(WidgetImportValidator::InvalidWidgetYamlError)
        end
      end

      context "when the yaml contains a hash of widgets" do
        let(:uploaded_content) { {"MiqWidget" => {}}.to_yaml }

        it "does not raise any errors" do
          expect { widget_import_validator.determine_validity(import_file_upload) }.to_not raise_error
        end
      end

      context "when the yaml has no widgets" do
        let(:uploaded_content) { [{}].to_yaml }

        it "raises a WidgetImportValidator::InvalidWidgetYamlError" do
          expect do
            widget_import_validator.determine_validity(import_file_upload)
          end.to raise_error(WidgetImportValidator::InvalidWidgetYamlError)
        end
      end

      context "when the yaml is a simple string" do
        let(:uploaded_content) { "lol".to_yaml }

        it "raises a WidgetImportValidator::InvalidWidgetYamlError" do
          expect do
            widget_import_validator.determine_validity(import_file_upload)
          end.to raise_error(WidgetImportValidator::InvalidWidgetYamlError)
        end
      end
    end

    context "when the yaml is invalid yaml" do
      let(:uploaded_content) { "-\nbad yaml" }

      it "raises a WidgetImportValidator::NonYamlError" do
        expect do
          widget_import_validator.determine_validity(import_file_upload)
        end.to raise_error(WidgetImportValidator::NonYamlError)
      end
    end
  end
end
