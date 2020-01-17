RSpec.describe ScanningMixin do
  let(:test_instance) do
    Class.new do
      include ScanningMixin
    end.new
  end

  describe "#update_job_message" do
    let(:job_guid) { "qwerty" }
    let(:message) { "Test message Blah" }
    let(:ost) do
      allow(MiqServer).to receive(:my_zone)
      OpenStruct.new(:taskid => job_guid)
    end

    it "adds to MiqQueue call to 'Job#update_message'" do
      test_instance.update_job_message(ost, message)
      queue_item = MiqQueue.find_by(:class_name => "Job", :method_name => "update_message")
      expect(queue_item.args[0]).to eq job_guid
    end
  end
end
