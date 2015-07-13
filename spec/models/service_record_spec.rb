require "spec_helper"

describe ServiceResource do
  context "default values" do
    before(:each) do
      @resource = ServiceResource.new
    end

    it "should default group_idx to 0" do
      @resource.group_idx.should == 0
    end

    it "should default scaling_min to 1" do
      @resource.scaling_min.should == 1
    end

    it "should default scaling_max to -1" do
      @resource.scaling_max.should == -1
    end
  end
end
