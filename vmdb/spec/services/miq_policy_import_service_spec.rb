require "spec_helper"

describe MiqPolicyImportService do
  let(:miq_policy_import_service) { described_class.new }
  let(:import_file_upload) { active_record_instance_double("ImportFileUpload") }
  let(:miq_queue) { active_record_instance_double("MiqQueue") }

  describe "#cancel_import" do
    before do
      import_file_upload.stub(:destroy)
      miq_queue.stub(:destroy)
      ImportFileUpload.stub(:find).with(123).and_return(import_file_upload)
      MiqQueue.stub(:first).with(
        :conditions => {
          :class_name  => "ImportFileUpload",
          :instance_id => 123,
          :method_name => "destroy"
        }
      ).and_return(miq_queue)
    end

    it "destroys the import file upload" do
      import_file_upload.should_receive(:destroy)
      miq_policy_import_service.cancel_import(123)
    end

    it "destroys the queue item" do
      miq_queue.should_receive(:destroy)
      miq_policy_import_service.cancel_import(123)
    end
  end

  describe "#import_policy" do
    before do
      import_file_upload.stub(:destroy)
      import_file_upload.stub(:uploaded_yaml_content).and_return("upload_content")
      miq_queue.stub(:destroy)

      ImportFileUpload.stub(:find).with(123).and_return(import_file_upload)
      MiqPolicy.stub(:import_from_array)
      MiqQueue.stub(:first).with(
        :conditions => {
          :class_name  => "ImportFileUpload",
          :instance_id => 123,
          :method_name => "destroy"
        }
      ).and_return(miq_queue)
    end

    it "imports the policy using MiqPolicy" do
      MiqPolicy.should_receive(:import_from_array).with("upload_content", :save => true)
      miq_policy_import_service.import_policy(123)
    end

    it "destroys the import file upload" do
      import_file_upload.should_receive(:destroy)
      miq_policy_import_service.import_policy(123)
    end

    it "destroys the queue item" do
      miq_queue.should_receive(:destroy)
      miq_policy_import_service.import_policy(123)
    end
  end

  describe "#store_for_import" do
    let(:file_contents) { "file contents" }
    let(:import_file_upload) { active_record_instance_double("ImportFileUpload", :id => 1).as_null_object }

    before do
      MiqPolicy.stub(:import).with("file contents").and_return(:uploaded => "content")
      MiqQueue.stub(:put_or_update)
      ImportFileUpload.stub(:create).and_return(import_file_upload)
    end

    it "stores the import file upload" do
      import_file_upload.should_receive(:store_policy_import_data).with("---\n:uploaded: content\n")
      miq_policy_import_service.store_for_import(file_contents)
    end

    it "returns the import file upload" do
      miq_policy_import_service.store_for_import(file_contents).should == import_file_upload
    end

    it "queues deletion of the object" do
      Timecop.freeze(2014, 3, 4) do
        MiqQueue.should_receive(:put_or_update).with(
          :class_name  => "ImportFileUpload",
          :instance_id => 1,
          :deliver_on  => 1.day.from_now,
          :method_name => "destroy"
        )
        miq_policy_import_service.store_for_import(file_contents)
      end
    end
  end
end
