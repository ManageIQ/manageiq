require_relative 'spec_helper'

describe ManageiqForeman::Inventory do
  describe "#refresh_configuration" do
    it "fetches location details" do
      connection = double("connection")
      expect(connection).to receive(:all).with(:hosts).and_return([{"location_id" => 5}])
      expect(connection).to receive(:all).with(:hostgroups).and_return([{}])
      expect(connection).to receive(:load_details).with(Array, :hostgroups)
      inventory = described_class.new(connection)

      inventory.refresh_configuration
    end

    it "skips location details if already fetched" do
      connection = double("connection")
      expect(connection).to receive(:all).with(:hosts).and_return([{"location_id" => 5}])
      expect(connection).to receive(:all).with(:hostgroups).and_return([{"locations" => {}}])
      expect(connection).not_to receive(:load_details)
      inventory = described_class.new(connection)

      inventory.refresh_configuration
    end

    it "skips location details if not needed" do
      connection = double("connection")
      expect(connection).to receive(:all).with(:hosts).and_return([])
      expect(connection).to receive(:all).with(:hostgroups).and_return([])
      expect(connection).not_to receive(:load_details)
      inventory = described_class.new(connection)

      inventory.refresh_configuration
    end

    it "fetches organization details" do
      connection = double("connection")
      expect(connection).to receive(:all).with(:hosts).and_return([{"organization_id" => 5}])
      expect(connection).to receive(:all).with(:hostgroups).and_return([{}])
      expect(connection).to receive(:load_details).with(Array, :hostgroups)
      inventory = described_class.new(connection)

      inventory.refresh_configuration
    end
  end
end
