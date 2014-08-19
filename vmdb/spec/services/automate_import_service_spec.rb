require "spec_helper"
require "miq_ae_yaml_import_zipfs"

describe AutomateImportService do
  let(:automate_import_service) { described_class.new }

  describe "#cancel_import" do
    let(:import_file_upload) { active_record_instance_double("ImportFileUpload", :id => 42) }

    before do
      ImportFileUpload.stub(:find).with("42").and_return(import_file_upload)
      import_file_upload.stub(:destroy)

      MiqQueue.stub(:unqueue)
    end

    it "destroys the import file upload" do
      import_file_upload.should_receive(:destroy)
      automate_import_service.cancel_import("42")
    end

    it "destroys the queued deletion" do
      MiqQueue.should_receive(:unqueue).with(
        :class_name  => "ImportFileUpload",
        :instance_id => 42,
        :method_name => "destroy"
      )
      automate_import_service.cancel_import("42")
    end
  end

  describe "#import_datastore" do
    let(:import_file_upload) { active_record_instance_double("ImportFileUpload", :binary_blob => binary_blob) }
    let(:binary_blob) { active_record_instance_double("BinaryBlob", :binary => "binary") }

    let(:miq_ae_import) { instance_double("MiqAeYamlImportZipfs") }

    let(:removable_entry) { double(:name => "carrot/something_else") }

    before do
      import_options = {
        "import_as" => "potato",
        "overwrite" => true,
        "zip_file"  => "automate_temporary_zip.zip"
      }
      MiqAeImport.stub(:new).with("carrot", import_options).and_return(miq_ae_import)
      miq_ae_import.stub(:remove_unrelated_entries)
      miq_ae_import.stub(:all_namespace_files).and_return([
        removable_entry,
        double(:name => "something_else/carrot"),
      ])
      miq_ae_import.stub(:remove_entry)
      miq_ae_import.stub(:update_sorted_entries)
      miq_ae_import.stub(:import)
    end

    it "removes unrelated entries" do
      miq_ae_import.should_receive(:remove_unrelated_entries).with("carrot")
      automate_import_service.import_datastore(import_file_upload, "carrot", "potato", ["starch"])
    end

    it "removes the correct file" do
      miq_ae_import.should_receive(:remove_entry).with(removable_entry)
      automate_import_service.import_datastore(import_file_upload, "carrot", "potato", ["starch"])
    end

    it "updates the sorted entries" do
      miq_ae_import.should_receive(:update_sorted_entries)
      automate_import_service.import_datastore(import_file_upload, "carrot", "potato", ["starch"])
    end

    it "calls import" do
      miq_ae_import.should_receive(:import)
      automate_import_service.import_datastore(import_file_upload, "carrot", "potato", ["starch"])
    end
  end

  describe "#store_for_import" do
    let(:import_file_upload) { active_record_instance_double("ImportFileUpload", :id => 42).as_null_object }

    before do
      ImportFileUpload.stub(:create).and_return(import_file_upload)
      import_file_upload.stub(:store_binary_data_as_yml)
      MiqQueue.stub(:put)
    end

    it "stores the data" do
      import_file_upload.should_receive(:store_binary_data_as_yml).with("the data", "Automate import")
      automate_import_service.store_for_import("the data")
    end

    it "returns the imported file upload" do
      expect(automate_import_service.store_for_import("the data")).to eq(import_file_upload)
    end

    it "queues a deletion" do
      Timecop.freeze(2014, 3, 5) do
        MiqQueue.should_receive(:put).with(
          :class_name  => "ImportFileUpload",
          :instance_id => 42,
          :deliver_on  => 1.day.from_now,
          :method_name => "destroy"
        )

        automate_import_service.store_for_import("the data")
      end
    end
  end
end
