describe AutomateImportService do
  let(:automate_import_service) { described_class.new }

  describe "#cancel_import" do
    let(:import_file_upload) { double("ImportFileUpload", :id => 42) }

    before do
      allow(ImportFileUpload).to receive(:find).with("42").and_return(import_file_upload)
      allow(import_file_upload).to receive(:destroy)

      allow(MiqQueue).to receive(:unqueue)
    end

    it "destroys the import file upload" do
      expect(import_file_upload).to receive(:destroy)
      automate_import_service.cancel_import("42")
    end

    it "destroys the queued deletion" do
      expect(MiqQueue).to receive(:unqueue).with(
        :class_name  => "ImportFileUpload",
        :instance_id => 42,
        :method_name => "destroy"
      )
      automate_import_service.cancel_import("42")
    end
  end

  describe "#import_datastore" do
    let(:import_file_upload) { double("ImportFileUpload", :binary_blob => binary_blob) }
    let(:binary_blob) { double("BinaryBlob", :binary => "binary") }
    let(:miq_ae_import) { double("MiqAeYamlImportZipfs", :import_stats => "import stats") }
    let(:removable_entry) { double(:name => "carrot/something_else/namespace.yaml") }
    let(:removable_class_entry) { double(:name => "carrot/something_else.class/class.yaml") }

    before do
      import_options = {
        "import_as" => "potato",
        "overwrite" => true,
        "zip_file"  => "automate_temporary_zip.zip"
      }
      allow(MiqAeImport).to receive(:new).with("carrot", import_options).and_return(miq_ae_import)
      allow(miq_ae_import).to receive(:remove_unrelated_entries)
      allow(miq_ae_import).to receive(:all_namespace_files).and_return([
        removable_entry,
        double(:name => "something_else/carrot"),
      ])
      allow(miq_ae_import).to receive(:all_class_files).and_return([
        removable_class_entry,
        double(:name => "something_else/carrot.class/class.yaml")
      ])
      allow(miq_ae_import).to receive(:remove_entry)
      allow(miq_ae_import).to receive(:update_sorted_entries)
      allow(miq_ae_import).to receive(:import).and_return(true)
    end

    it "removes unrelated entries" do
      expect(miq_ae_import).to receive(:remove_unrelated_entries).with("carrot")
      automate_import_service.import_datastore(import_file_upload, "carrot", "potato", ["starch"])
    end

    it "removes the correct namespace file" do
      expect(miq_ae_import).to receive(:remove_entry).with(removable_entry)
      automate_import_service.import_datastore(import_file_upload, "carrot", "potato", ["starch"])
    end

    it "removes the correct class file" do
      expect(miq_ae_import).to receive(:remove_entry).with(removable_class_entry)
      automate_import_service.import_datastore(import_file_upload, "carrot", "potato", ["starch"])
    end

    it "updates the sorted entries" do
      expect(miq_ae_import).to receive(:update_sorted_entries)
      automate_import_service.import_datastore(import_file_upload, "carrot", "potato", ["starch"])
    end

    it "calls import" do
      expect(miq_ae_import).to receive(:import)
      automate_import_service.import_datastore(import_file_upload, "carrot", "potato", ["starch"])
    end

    it "returns the import stats" do
      expect(automate_import_service.import_datastore(import_file_upload, "carrot", "potato", ["starch"])).to eq(
        "import stats"
      )
    end

    context "when the domain name to import to is blank" do
      it "creates a new MiqAeImport with the correct import options" do
        expect(MiqAeImport).to receive(:new).with(
          "carrot",
          "import_as" => "carrot",
          "overwrite" => true,
          "zip_file"  => "automate_temporary_zip.zip"
        ).and_return(miq_ae_import)
        automate_import_service.import_datastore(import_file_upload, "carrot", "", ["starch"])
      end
    end
  end

  describe "#store_for_import" do
    let(:import_file_upload) { double("ImportFileUpload", :id => 42).as_null_object }

    before do
      allow(ImportFileUpload).to receive(:create).and_return(import_file_upload)
      allow(import_file_upload).to receive(:store_binary_data_as_yml)
      allow(MiqQueue).to receive(:put)
    end

    it "stores the data" do
      expect(import_file_upload).to receive(:store_binary_data_as_yml).with("the data", "Automate import")
      automate_import_service.store_for_import("the data")
    end

    it "returns the imported file upload" do
      expect(automate_import_service.store_for_import("the data")).to eq(import_file_upload)
    end

    it "queues a deletion" do
      Timecop.freeze(2014, 3, 5) do
        expect(MiqQueue).to receive(:put).with(
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
