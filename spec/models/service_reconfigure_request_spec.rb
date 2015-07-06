require "spec_helper"

describe ServiceReconfigureRequest do
  let(:request) do
    described_class.new(:options => {:src_id => 123})
  end

  describe "#requested_task_idx" do
    it "should be associated to the source Service" do
      request.requested_task_idx.should == [123]
    end
  end

  describe "#my_role" do
    it "should be 'ems_operations'" do
      request.my_role.should == 'ems_operations'
    end
  end
end
