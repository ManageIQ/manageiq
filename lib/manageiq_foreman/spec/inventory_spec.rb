require 'spec_helper'

describe ManageiqForeman::Inventory do
  describe "#from_attributes" do
    it "accepts a hash" do
      expect(ManageiqForeman::Connection).to receive(:new).with(FOREMAN)
      described_class.from_attributes(FOREMAN)
    end
  end

  describe "#refresh" do
    subject(:inventory) { described_class.new(FOREMAN) }
  end

  # describe "#ems_inv_to_hashes" do
  #   it "returns" do
  #     inventory.ems_inv_to_hashes(provider)
  #   end
  # end

  # describe "#ems_hosts" do
  #   inventory.ems_hosts()
  # end
  # describe ""

end
