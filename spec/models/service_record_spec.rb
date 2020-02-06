RSpec.describe ServiceResource do
  context "default values" do
    before do
      @resource = ServiceResource.new
    end

    it "should default group_idx to 0" do
      expect(@resource.group_idx).to eq(0)
    end

    it "should default scaling_min to 1" do
      expect(@resource.scaling_min).to eq(1)
    end

    it "should default scaling_max to -1" do
      expect(@resource.scaling_max).to eq(-1)
    end
  end
end
