require "spec_helper"

describe AutomateImportService do
  let(:automate_import_service) { described_class.new }

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
