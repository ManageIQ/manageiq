require "spec_helper"

RSpec.describe VimPerformanceState do
  describe "#vm_count_total" do
    it "will return the total vms regardless of mode" do
      state_data = {:assoc_ids => {:vms => {:on => [1], :off => [2]}}}
      actual = described_class.new(:state_data => state_data)
      expect(actual.vm_count_total).to eq(2)
    end
  end

  describe "#host_count_total" do
    it "will return the total hosts regardless of mode" do
      state_data = {:assoc_ids => {:hosts => {:on => [1], :off => [2]}}}
      actual = described_class.new(:state_data => state_data)
      expect(actual.host_count_total).to eq(2)
    end
  end
end
