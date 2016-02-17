describe MiqPolicyImportService do
  let(:miq_policy_import_service) { described_class.new }
  let(:import_file_upload) { double("ImportFileUpload") }
  let(:miq_queue) do
    FactoryGirl.create(:miq_queue, :class_name => "ImportFileUpload", :instance_id => 123, :method_name => "destroy")
  end

  describe "#cancel_import" do
    before do
      allow(import_file_upload).to receive(:destroy)
      allow(ImportFileUpload).to receive(:find).with(123).and_return(import_file_upload)
      miq_queue
    end

    it "destroys the import file upload" do
      expect(import_file_upload).to receive(:destroy)
      miq_policy_import_service.cancel_import(123)
    end

    it "destroys the queue item" do
      miq_policy_import_service.cancel_import(123)
      expect(MiqQueue.where(:id => miq_queue.id)).not_to be_exists
    end
  end

  describe "#import_policy" do
    before do
      miq_queue
      allow(import_file_upload).to receive(:destroy)
      allow(import_file_upload).to receive(:uploaded_yaml_content).and_return("upload_content")

      allow(ImportFileUpload).to receive(:find).with(123).and_return(import_file_upload)
      allow(MiqPolicy).to receive(:import_from_array)
    end

    it "imports the policy using MiqPolicy" do
      expect(MiqPolicy).to receive(:import_from_array).with("upload_content", :save => true)
      miq_policy_import_service.import_policy(123)
    end

    it "destroys the import file upload" do
      expect(import_file_upload).to receive(:destroy)
      miq_policy_import_service.import_policy(123)
    end

    it "destroys the queue item" do
      miq_policy_import_service.import_policy(123)
      expect(MiqQueue.where(:id => miq_queue.id)).not_to be_exists
    end
  end

  describe "#store_for_import" do
    let(:file_contents) { "file contents" }
    let(:import_file_upload) { double("ImportFileUpload", :id => 1).as_null_object }

    context "when the import does not raise an error" do
      before do
        allow(MiqPolicy).to receive(:import).with("file contents", :preview => true).and_return(:uploaded => "content")
        allow(MiqQueue).to receive(:put_or_update)
        allow(ImportFileUpload).to receive(:create).and_return(import_file_upload)
      end

      it "stores the import file upload" do
        expect(import_file_upload).to receive(:store_binary_data_as_yml).with("---\n:uploaded: content\n", "Policy import")
        miq_policy_import_service.store_for_import(file_contents)
      end

      it "returns the import file upload" do
        expect(miq_policy_import_service.store_for_import(file_contents)).to eq(import_file_upload)
      end

      it "queues deletion of the object" do
        Timecop.freeze(2014, 3, 4) do
          expect(MiqQueue).to receive(:put_or_update).with(
            :class_name  => "ImportFileUpload",
            :instance_id => 1,
            :deliver_on  => 1.day.from_now,
            :method_name => "destroy"
          )
          miq_policy_import_service.store_for_import(file_contents)
        end
      end
    end

    context "when the import does raise an error" do
      before do
        allow(MiqPolicy).to receive(:import).with("file contents", :preview => true).and_raise
      end

      it "reraises an InvalidMiqPolicyYaml error with a message" do
        expect { miq_policy_import_service.store_for_import(file_contents) }.to raise_error(
          MiqPolicyImportService::InvalidMiqPolicyYaml, "Invalid YAML file"
        )
      end
    end
  end
end
