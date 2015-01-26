require_relative 'spec_helper'

describe ManageiqForeman::Inventory do
  describe "#from_attributes" do
    it "accepts a hash" do
      expect(ManageiqForeman::Connection).to receive(:new).with(:base_url => "example.com")
      described_class.from_attributes(:base_url => "example.com")
    end
  end
end
