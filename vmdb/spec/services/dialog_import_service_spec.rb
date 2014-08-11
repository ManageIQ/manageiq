require "spec_helper"
require "dialog_field_importer"
require "dialog_import_validator"

describe DialogImportService do
  let(:dialog_import_service) { described_class.new(dialog_field_importer, dialog_import_validator) }
  let(:dialog_field_importer) { instance_double("DialogFieldImporter") }
  let(:dialog_import_validator) { instance_double("DialogImportValidator") }

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
       {"label" => "Test2", "dialog_tabs" => [], "description" => "potato"}]
    end

    let(:not_dialogs) { [{"this is not" => "a dialog"}] }

    before do
      built_dialog_field = DialogField.create(:name => "dialog_field")
      dialog_field_importer.stub(:import_field).and_return(built_dialog_field)
    end
  end

  describe "#cancel_import" do
    let(:import_file_upload) { active_record_instance_double("ImportFileUpload", :id => 123) }
    let(:miq_queue) { active_record_instance_double("MiqQueue") }

    before do
      ImportFileUpload.stub(:find).with("123").and_return(import_file_upload)
      import_file_upload.stub(:destroy)

      MiqQueue.stub(:unqueue)
    end

    it "destroys the import file upload" do
      import_file_upload.should_receive(:destroy)
      dialog_import_service.cancel_import("123")
    end

    it "destroys the queued deletion" do
      MiqQueue.should_receive(:unqueue).with(
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
        YAML.stub(:load_file).with(filename).and_return(dialogs)
      end

      context "when there is an existing dialog" do
        before do
          Dialog.create!(:label => "Test2")
        end

        it "does not create a third dialog" do
          dialog_import_service.import_from_file(filename)
          Dialog.count.should == 2
        end

        it "yields the given block" do
          block_called = false
          dialog_import_service.import_from_file(filename) do |_|
            block_called = true
          end

          block_called.should be_true
        end
      end

      context "when there is not an existing dialog" do
        it "builds a new dialog" do
          dialog_import_service.import_from_file(filename)
          Dialog.first.should_not be_nil
        end

        it "builds a dialog tab associated to the dialog" do
          dialog_import_service.import_from_file(filename)
          dialog = Dialog.first
          DialogTab.first.dialog.should == dialog
        end

        it "builds a dialog group associated to the dialog tab" do
          dialog_import_service.import_from_file(filename)
          dialog_tab = DialogTab.first
          DialogGroup.first.dialog_tab.should == dialog_tab
        end

        it "imports the dialog fields" do
          dialog_field_importer.should_receive(:import_field).with(dialog_fields[0])
          dialog_import_service.import_from_file(filename)
        end
      end
    end

    context "when the dialog_field_importer raises an InvalidDialogFieldTypeError" do
      before do
        YAML.stub(:load_file).with(filename).and_return(dialogs)
        dialog_field_importer.stub(:import_field).and_raise(
          DialogFieldImporter::InvalidDialogFieldTypeError.new("Custom Message")
        )
      end

      it "re-raises" do
        expect {
          dialog_import_service.import_from_file(filename)
        }.to raise_error(DialogFieldImporter::InvalidDialogFieldTypeError, "Custom Message")
      end
    end

    context "when the loaded yaml does not return dialogs" do
      before do
        YAML.stub(:load_file).with(filename).and_return(not_dialogs)
      end

      it "raises a ParsedNonDialogYamlError" do
        expect {
          dialog_import_service.import_from_file(filename)
        }.to raise_error(DialogImportService::ParsedNonDialogYamlError)
      end
    end
  end

  describe "#import_service_dialogs" do
    include_context "DialogImportService dialog setup"

    let(:miq_queue) { active_record_instance_double("MiqQueue") }
    let(:yaml_data) { "the yaml" }
    let(:import_file_upload) do
      active_record_instance_double("ImportFileUpload", :id => 123, :uploaded_content => yaml_data)
    end
    let(:dialogs_to_import) { %w(Test Test2) }

    before do
      import_file_upload.stub(:destroy)
      MiqQueue.stub(:unqueue)
    end

    shared_examples_for "DialogImportService#import_service_dialogs that destroys temporary data" do
      it "destroys the import file upload" do
        import_file_upload.should_receive(:destroy)
        dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
      end

      it "unqueues the miq_queue item" do
        MiqQueue.should_receive(:unqueue).with(
          :class_name  => "ImportFileUpload",
          :instance_id => 123,
          :method_name => "destroy"
        )
        dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
      end
    end

    context "when the YAML loaded is dialogs" do
      before do
        YAML.stub(:load).with(yaml_data).and_return(dialogs)
      end

      context "when the list of dialogs to import from the yaml includes an existing dialog" do
        before do
          Dialog.create!(:label => "Test2", :description => "not potato")
        end

        it_behaves_like "DialogImportService#import_service_dialogs that destroys temporary data"

        it "overwrites the existing dialog" do
          dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
          Dialog.where(:label => "Test2").first.description.should == "potato"
        end
      end

      context "when the list of dialogs to import from the yaml do not include an existing dialog" do
        it_behaves_like "DialogImportService#import_service_dialogs that destroys temporary data"

        it "builds a new dialog" do
          dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
          Dialog.first.should_not be_nil
        end

        it "builds a dialog tab associated to the dialog" do
          dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
          dialog = Dialog.first
          DialogTab.first.dialog.should == dialog
        end

        it "builds a dialog group associated to the dialog tab" do
          dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
          dialog_tab = DialogTab.first
          DialogGroup.first.dialog_tab.should == dialog_tab
        end

        it "imports the dialog fields" do
          dialog_field_importer.should_receive(:import_field).with(dialog_fields[0])
          dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
        end
      end

      context "when the list of dialogs is nil" do
        let(:dialogs_to_import) { nil }

        it_behaves_like "DialogImportService#import_service_dialogs that destroys temporary data"

        it "does not error" do
          expect {
            dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
          }.to_not raise_error
        end
      end
    end

    context "when the YAML loaded is not dialog format" do
      before do
        YAML.stub(:load).with(yaml_data).and_return(not_dialogs)
      end

      it "raises a ParsedNonDialogYamlError" do
        expect {
          dialog_import_service.import_service_dialogs(import_file_upload, dialogs_to_import)
        }.to raise_error(DialogImportService::ParsedNonDialogYamlError)
      end
    end
  end

  describe "#store_for_import" do
    let(:import_file_upload) { active_record_instance_double("ImportFileUpload", :id => 123).as_null_object }

    before do
      MiqQueue.stub(:put)
      ImportFileUpload.stub(:create).and_return(import_file_upload)
      import_file_upload.stub(:store_binary_data_as_yml)
    end

    context "when the imported file does not raise any errors while determining validity" do
      before do
        dialog_import_validator.stub(:determine_validity).with(import_file_upload).and_return(nil)
      end

      it "stores the data" do
        import_file_upload.should_receive(:store_binary_data_as_yml).with("the data", "Service dialog import")
        dialog_import_service.store_for_import("the data")
      end

      it "returns the imported file upload" do
        dialog_import_service.store_for_import("the data").should == import_file_upload
      end

      it "queues a deletion" do
        Timecop.freeze(2014, 3, 5) do
          MiqQueue.should_receive(:put).with(
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
        dialog_import_validator.stub(:determine_validity).with(import_file_upload).and_raise(error_to_be_raised)
      end

      it "reraises with the original error" do
        expect {
          dialog_import_service.store_for_import("the data")
        }.to raise_error(DialogImportValidator::InvalidDialogFieldTypeError, "Test message")
      end

      it "queues a deletion" do
        Timecop.freeze(2014, 3, 5) do
          MiqQueue.should_receive(:put).with(
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
