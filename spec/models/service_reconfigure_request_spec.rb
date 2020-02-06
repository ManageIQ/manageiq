RSpec.describe ServiceReconfigureRequest do
  let(:request) do
    described_class.new(:options => {:src_id => 123})
  end

  describe "#requested_task_idx" do
    it "should be associated to the source Service" do
      expect(request.requested_task_idx).to eq([123])
    end
  end

  describe "#my_role" do
    it "should be 'ems_operations'" do
      expect(request.my_role).to eq('ems_operations')
    end
  end
end
