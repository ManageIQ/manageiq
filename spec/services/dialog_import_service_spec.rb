require "dialog_field_importer"
require "dialog_import_validator"

describe DialogImportService do
  let(:dialog_import_service) { described_class.new(dialog_field_importer, dialog_import_validator) }
  let(:dialog_field_importer) { double("DialogFieldImporter") }
  let(:dialog_import_validator) { double("DialogImportValidator") }

  shared_context "DialogImportService dialog setup" do
    let(:dialog_fields) do
      [{"name" => "FavoriteColor", "label" => "Favorite Color"}]
    end

    let(:dialog_groups) do
      [{"label" => "New Box", "dialog_fields" => dialog_fields}]
    end

    let(:dialog_tabs) do
      [{"label" => "New Tab", "dialog_groups" => dialog_groups}]
    end

    let(:dialogs) do
      [{"label" => "Test", "dialog_tabs" => dialog_tabs},
       {"label" => "Test2", "dialog_tabs" => dialog_tabs, "description" => "potato"}]
    end

    let(:not_dialogs) { [{"this is not" => "a dialog"}] }

    before do
      built_dialog_field = DialogField.create(:name => "dialog_field")
      allow(dialog_field_importer).to receive(:import_field).and_return(built_dialog_field)
    end
  end

  describe "#cancel_import" do
    let(:import_file_upload) { double("ImportFileUpload", :id => 123) }
    let(:miq_queue) { double("MiqQueue") }

    before do
      allow(ImportFileUpload).to receive(:find).with("123").and_return(import_file_upload)
      allow(import_file_upload).to receive(:destroy)

      allow(MiqQueue).to receive(:unqueue)
    end

    it "destroys the import file upload" do
      expect(import_file_upload).to receive(:destroy)
      dialog_import_service.cancel_import("123")
    end

    it "destroys the queued deletion" do
      expect(MiqQueue).to receive(:unqueue).with(
        :class_name  => "ImportFileUpload",
        :instance_id => 123,
        :method_name => "destroy"
      )
      dialog_import_service.cancel_import("123")
    end
  end

  describe "#import_from_file" do
    include_context "DialogImportService dialog setup"

    let(:filename) { "filename" }

    context "when the loaded yaml returns dialogs" do
      before do
        allow(YAML).to receive(:load_file).with(filename).and_return(dialogs)
      end

      context "when there is an existing dialog" do
        before do
          FactoryGirl.create(:dialog, :label => "Test2")
        end

        it "does not create a third dialog" do
          dialog_import_service.import_from_file(filename)
          expect(Dialog.count).to eq(2)
        end

        it "yields the given block" do
          block_called = false
          dialog_import_service.import_from_file(filename) do |_|
            block_called = true
          end

          expect(block_called).to be_truthy
        end
      end

      context "when there is not an existing dialog" do
        it "builds a new dialog" do
          dialog_import_service.import_from_file(filename)
          expect(Dialog.first).not_to be_nil
        end

        it "builds a dialog tab associated to the dialog" do
          dialog_import_service.import_from_file(filename)
          dialog = Dialog.first
          expect(DialogTab.first.dialog).to eq(dialog)
        end

        it "builds a dialog group associated to the dialog tab" do
          dialog_import_service.import_from_file(filename)
          dialog_tab = DialogTab.first
          expect(DialogGroup.first.dialog_tab).to eq(dialog_tab)
        end

        it "imports the dialog fields" do
          expect(dialog_field_importer).to receive(:import_field).with(dialog_fields[0])
          dialog_import_service.import_from_file(filename)
        end
      end
    end

    context "when the dialog_field_importer raises an InvalidDialogFieldTypeError" do
      before do
        allow(YAML).to receive(:load_file).with(filename).and_return(dialogs)
        allow(dialog_field_importer).to receive(:import_field).and_raise(
          DialogFieldImporter::InvalidDialogFieldTypeError.new("Custom Message")
        )
      end

      it "re-raises" do
        expect do
          dialog_import_service.import_from_file(filename)
        end.to raise_error(DialogFieldImporter::InvalidDialogFieldTypeError, "Custom Message")
      end
    end

    context "when the loaded yaml does not return dialogs" do
      before do
        allow(YAML).to receive(:load_file).with(filename).and_return(not_dialogs)
      end

      it "raises a ParsedNonDialogYamlError" do
        expect do
          dialog_import_service.import_from_file(filename)
        end.to raise_error(DialogImportService::ParsedNonDialogYamlError)
      end
    end
  end

  describe "#import_all_service_dialogs_from_yaml_file" do
    include_context "DialogImportService dialog setup"

    before do
      allow(YAML).to receive(:load_file).with("filename").and_return(dialogs)
    end

    context "when there is already an existing dialog" do
      before do
        FactoryGirl.create(:dialog, :label => "Test2", :description => "not potato")
      end

      it "overwrites the existing dialog" do
        dialog_import_service.import_all_service_dialogs_from_yaml_file("filename")
        expect(Dialog.where(:label => "Test2").first.description).to eq("potato")
      end
    end

    context "when there are no existing dialogs" do
      it "builds a new dialog" do
        dialog_import_service.import_all_service_dialogs_from_yaml_file("filename")
        expect(Dialog.first).not_to be_nil
      end

      it "builds a dialog tab associated to the dialog" do
        dialog_import_service.import_all_service_dialogs_from_yaml_file("filename")
        dialog = Dialog.first
        expect(DialogTab.first.dialog).to eq(dialog)
      end

      it "builds a dialog group associated to the dialog tab" do
        dialog_import_service.import_all_service_dialogs_from_yaml_file("filename")
        dialog_tab = DialogTab.first
        expect(DialogGroup.first.dialog_tab).to eq(dialog_tab)
      end

      it "imports the dialog fields" do
        expect(dialog_field_importer).to receive(:import_field).with(dialog_fields[0])
        dialog_import_service.import_all_service_dialogs_from_yaml_file("filename")
      end
    end
  end

  describe "#import_service_dialogs" do
    include_context "DialogImportService dialog setup"

    let(:miq_queue) { double("MiqQueue") }
    let(:yaml_data) { "the yaml" }
    let(:import_file_upload) do
      double("ImportFileUpload", :id => 123, :uploaded_content => yaml_data)
    end
    let(:dialogs_to_import) { %w(Test Test2) }

    before do
      allow(import_file_upload).to receive(:destroy)
      allow(MiqQueue).to receive(:unqueue)
    end

    shared_examples_for "DialogImportService#import_service_dialogs that destroys temporary data" do
      it "destroys the import file upload" do
        expect(import_file_upload).to receive(:destroy)
        dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
      end

      it "unqueues the miq_queue item" do
        expect(MiqQueue).to receive(:unqueue).with(
          :class_name  => "ImportFileUpload",
          :instance_id => 123,
          :method_name => "destroy"
        )
        dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
      end
    end

    context "when the YAML loaded is dialogs" do
      before do
        allow(YAML).to receive(:load).with(yaml_data).and_return(dialogs)
      end

      context "when the list of dialogs to import from the yaml includes an existing dialog" do
        before do
          FactoryGirl.create(:dialog, :label => "Test2", :description => "not potato")
        end

        it_behaves_like "DialogImportService#import_service_dialogs that destroys temporary data"

        it "overwrites the existing dialog" do
          dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
          expect(Dialog.where(:label => "Test2").first.description).to eq("potato")
        end
      end

      context "when the list of dialogs to import from the yaml do not include an existing dialog" do
        it_behaves_like "DialogImportService#import_service_dialogs that destroys temporary data"

        it "builds a new dialog" do
          dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
          expect(Dialog.first).not_to be_nil
        end

        it "builds a dialog tab associated to the dialog" do
          dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
          dialog = Dialog.first
          expect(DialogTab.first.dialog).to eq(dialog)
        end

        it "builds a dialog group associated to the dialog tab" do
          dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
          dialog_tab = DialogTab.first
          expect(DialogGroup.first.dialog_tab).to eq(dialog_tab)
        end

        it "imports the dialog fields" do
          expect(dialog_field_importer).to receive(:import_field).with(dialog_fields[0])
          dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
        end
      end

      context "when the list of dialogs is nil" do
        let(:dialogs_to_import) { nil }

        it_behaves_like "DialogImportService#import_service_dialogs that destroys temporary data"

        it "does not error" do
          expect do
            dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
          end.to_not raise_error
        end
      end
    end

    context "when the YAML loaded is not dialog format" do
      before do
        allow(YAML).to receive(:load).with(yaml_data).and_return(not_dialogs)
      end

      it "raises a ParsedNonDialogYamlError" do
        expect do
          dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
        end.to raise_error(DialogImportService::ParsedNonDialogYamlError)
      end
    end
  end

  describe "#store_for_import" do
    let(:import_file_upload) { double("ImportFileUpload", :id => 123).as_null_object }

    before do
      allow(MiqQueue).to receive(:put)
      allow(ImportFileUpload).to receive(:create).and_return(import_file_upload)
      allow(import_file_upload).to receive(:store_binary_data_as_yml)
    end

    context "when the imported file does not raise any errors while determining validity" do
      before do
        allow(dialog_import_validator).to receive(:determine_validity).with(import_file_upload).and_return(nil)
      end

      it "stores the data" do
        expect(import_file_upload).to receive(:store_binary_data_as_yml).with("the data", "Service dialog import")
        dialog_import_service.store_for_import("the data")
      end

      it "returns the imported file upload" do
        expect(dialog_import_service.store_for_import("the data")).to eq(import_file_upload)
      end

      it "queues a deletion" do
        Timecop.freeze(2014, 3, 5) do
          expect(MiqQueue).to receive(:put).with(
            :class_name  => "ImportFileUpload",
            :instance_id => 123,
            :deliver_on  => 1.day.from_now,
            :method_name => "destroy"
          )

          dialog_import_service.store_for_import("the data")
        end
      end
    end

    context "when the imported file raises an error while determining validity" do
      before do
        error_to_be_raised = DialogImportValidator::InvalidDialogFieldTypeError.new("Test message")
        allow(dialog_import_validator).to receive(:determine_validity).with(import_file_upload).and_raise(error_to_be_raised)
      end

      it "reraises with the original error" do
        expect do
          dialog_import_service.store_for_import("the data")
        end.to raise_error(DialogImportValidator::InvalidDialogFieldTypeError, "Test message")
      end

      it "queues a deletion" do
        Timecop.freeze(2014, 3, 5) do
          expect(MiqQueue).to receive(:put).with(
            :class_name  => "ImportFileUpload",
            :instance_id => 123,
            :deliver_on  => 1.day.from_now,
            :method_name => "destroy"
          )

          begin
            dialog_import_service.store_for_import("the data")
          rescue DialogImportValidator::InvalidDialogFieldTypeError
            nil
          end
        end
      end
    end
  end
end
