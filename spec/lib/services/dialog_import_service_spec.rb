require "dialog_field_importer"
require "dialog_import_validator"

RSpec.describe DialogImportService do
  let(:dialog_import_service) { described_class.new(dialog_field_importer, dialog_import_validator) }
  let(:dialog_field_importer) { double("DialogFieldImporter") }
  let(:dialog_import_validator) { double("DialogImportValidator") }

  shared_context "DialogImportService dialog setup" do
    let(:dialog_fields) do
      [{"name" => "FavoriteColor", "label" => "Favorite Color"},
       {"name" => "dialog_field_2", "dialog_field_responders" => ["dialog_field"] }]
    end

    let(:dialog_groups) do
      [{"label" => "New Box", "dialog_fields" => dialog_fields, :position => 1}]
    end

    let(:dialog_tabs) do
      [{"label" => "New Tab", "dialog_groups" => dialog_groups, :position => 4}]
    end

    let(:dialogs) do
      [{"label" => "Test", "dialog_tabs" => dialog_tabs},
       {"label" => "Test2", "dialog_tabs" => dialog_tabs, "description" => "potato", "blueprint_id" => "456"}]
    end

    let(:dialogs_with_current_version) do
      [{"label" => "Test", "dialog_tabs" => dialog_tabs, 'export_version' => DialogImportService::CURRENT_DIALOG_VERSION}]
    end

    let(:not_dialogs) { [{"this is not" => "a dialog"}] }

    before do
      built_dialog_field = DialogField.create(:name => "dialog_field")
      built_dialog_field2 = DialogField.create(:name => "dialog_field_2")
      built_dialog_field3 = DialogField.create(:name => "df_with_old_trigger", :trigger_auto_refresh => true, :position => 0)
      built_dialog_field4 = DialogField.create(:name => "df_with_old_responder", :auto_refresh => true, :position => 1)
      allow(dialog_field_importer).to receive(:import_field).and_return(built_dialog_field, built_dialog_field2, built_dialog_field3, built_dialog_field4)
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
          FactoryBot.create(:dialog, :label => "Test2")
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
          expect(dialog_field_importer).to receive(:import_field).with(dialog_fields[0], DialogImportService::DEFAULT_DIALOG_VERSION)
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

    context "when the loaded yaml has unspecified version" do
      before do
        allow(YAML).to receive(:load_file).with(filename).and_return(dialogs)
      end

      it "defaults to DEFAULT_DIALOG_VERSION" do
        expect(dialog_field_importer).to receive(:import_field).with(dialog_fields[0], DialogImportService::DEFAULT_DIALOG_VERSION)
        dialog_import_service.import_from_file(filename)
      end
    end

    context "when the loaded yaml has valid version" do
      let(:version) { DialogImportService::CURRENT_DIALOG_VERSION }
      before do
        allow(YAML).to receive(:load_file).with(filename).and_return(dialogs_with_current_version)
      end

      it "the version gets used" do
        expect(dialog_field_importer).to receive(:import_field).with(dialog_fields[0], version)
        dialog_import_service.import_from_file(filename)
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
        FactoryBot.create(:dialog, :label => "Test2", :description => "not potato")
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
        expect(dialog_field_importer).to receive(:import_field).with(dialog_fields[0], DialogImportService::DEFAULT_DIALOG_VERSION)
        dialog_import_service.import_all_service_dialogs_from_yaml_file("filename")
      end

      it "sets only new associations when both new and old style exist" do
        expect do
          dialog_import_service.import_all_service_dialogs_from_yaml_file("filename")
        end.to change(DialogFieldAssociation, :count).by(1)

        expect(DialogField.find(DialogFieldAssociation.first.trigger_id).name).to eq("dialog_field_2")
        expect(DialogField.find(DialogFieldAssociation.first.respond_id).name).to eq("dialog_field")
      end
    end
  end

  describe "association creation" do
    context "with only old defunct associations present" do
      before do
        fields = []
        built_dialog_field3 = DialogField.create(:name => "df_with_old_trigger", :trigger_auto_refresh => true, :position => 0)
        built_dialog_field4 = DialogField.create(:name => "df_with_old_responder", :auto_refresh => true, :position => 1)
        fields << built_dialog_field3
        fields << built_dialog_field4
        allow(dialog_field_importer).to receive(:import_field).and_return(built_dialog_field3, built_dialog_field4)
        group = [{"label" => "New Box", "dialog_fields" => fields, :position => 1}]
        tab = [{"label" => "New Tab", "dialog_groups" => group, :position => 2}]
        dialog = [{"label" => "Test", "dialog_tabs" => tab}]
        allow(YAML).to receive(:load_file).with("filename").and_return(dialog)
      end

      it "sets only old associations when only old style exists" do
        expect do
          dialog_import_service.import_all_service_dialogs_from_yaml_file("filename")
        end.to change(DialogFieldAssociation, :count).by(1)

        expect(DialogField.find(DialogFieldAssociation.first.trigger_id).name).to eq("df_with_old_trigger")
        expect(DialogField.find(DialogFieldAssociation.first.respond_id).name).to eq("df_with_old_responder")
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
          FactoryBot.create(:dialog, :label => "Test2", :description => "not potato")
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
          expect(dialog_field_importer).to receive(:import_field).with(dialog_fields[0], DialogImportService::DEFAULT_DIALOG_VERSION)
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

    describe '#build_dialog_tabs' do
      let(:dialog_tabs) do
        {
          'dialog_tabs' => [
            {
              'label'         => 'new dialog tab',
              'dialog_groups' => [
                {
                  'label'         => 'group label',
                  'dialog_fields' => [
                    {
                      'name'  => 'field name',
                      'label' => 'field label'
                    }
                  ]
                }
              ]
            }
          ]
        }
      end

      it 'creates a new dialog_tab' do
        expect do
          DialogImportService.new.build_dialog_tabs(dialog_tabs)
        end.to change(DialogTab, :count).by(1)
      end
    end

    describe '#build_dialog_groups' do
      let(:dialog_groups) do
        {
          'dialog_groups' => [
            {
              'label'         => 'new group',
              'dialog_fields' => [
                {
                  'name'  => 'field name',
                  'label' => 'field label'
                }
              ]
            }
          ]
        }
      end

      it 'creates a new dialog_group' do
        expect do
          DialogImportService.new.build_dialog_groups(dialog_groups)
        end.to change(DialogGroup, :count).by(1)
      end
    end

    describe '#build_dialog_fields' do
      let(:dialog_fields) do
        {
          'dialog_fields' => [
            {'name' => 'field name', 'label' => 'field label', 'options' => {'name' => 'foo'}}
          ]
        }
      end

      it 'creates a new dialog_field' do
        expect do
          DialogImportService.new.build_dialog_fields(dialog_fields)
        end.to change(DialogField, :count).by(1)
      end

      it 'symbolizes the dialog field options' do
        fields = DialogImportService.new.build_dialog_fields(dialog_fields)
        expect(fields.first.options).to eq(:name => 'foo')
      end
    end
  end

  context '#import' do
    include_context "DialogImportService dialog setup"
    before do
      allow(dialog_import_validator).to receive(:determine_dialog_validity).with(dialogs.first).and_return(true)
    end

    it 'creates a new dialog with valid input' do
      expect do
        dialog_import_service.import(dialogs.first)
      end.to change(Dialog, :count).by(1)
    end

    it "creates field associations" do
      expect do
        dialog_import_service.import(dialogs.first)
      end.to change(DialogFieldAssociation, :count).by(1)
    end

    it 'will raise record invalid for invalid dialog' do
      dialog_import_service.import(dialogs.first)

      expect do
        dialog_import_service.import(dialogs.first)
      end.to raise_error(ActiveRecord::RecordInvalid, /Validation failed: Dialog: Name is not unique within region/)
        .and change { DialogTab.count }.by(0)
                                       .and change { DialogGroup.count }.by(0)
                                                                        .and change { DialogField.count }.by(0)
    end
  end

  describe "#build_associations" do
    let(:dialog) { instance_double("Dialog", :dialog_fields => dialog_fields) }
    let(:field1) { instance_double("DialogField", :id => 123, :name => "field1") }
    let(:field2) { instance_double("DialogField", :id => 321, :name => "field2") }
    let(:dialog_fields) { [field1, field2] }
    let(:association_list) { [{"field1" => %w(responder1 field2)}] }

    it "creates dialog field associations" do
      expect do
        dialog_import_service.build_associations(dialog, association_list)
      end.to change(DialogFieldAssociation, :count).by(1)
    end
  end

  describe "#build_association_list" do
    let(:dialog) do
      {
        "dialog_tabs" => [{
          "dialog_groups" => [{
            "dialog_fields" => [field1, field2, field3]
          }]
        }]
      }
    end

    let(:field1) { {"name" => "field1", "dialog_field_responders" => %w(field2 field3)} }
    let(:field2) { {"name" => "field2", "dialog_field_responders" => %w(field3)} }
    let(:field3) { {"name" => "field3", "dialog_field_responders" => []} }

    it "creates an association list of ids based on names" do
      expect(dialog_import_service.build_association_list(dialog)).to eq(
        [{"field1" => %w(field2 field3)}, {"field2" => %w(field3)}]
      )
    end

    it "association list doesn't include empty arrays" do
      expect(dialog_import_service.build_association_list(dialog)).not_to include("field3" => [])
    end
  end
end
