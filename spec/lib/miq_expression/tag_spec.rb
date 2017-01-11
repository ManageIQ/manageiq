require "rails_helper"

RSpec.describe MiqExpression::Tag do
  describe ".parse" do
    it "with managed-field" do
      field = "managed.location"
      expect(described_class.parse(field)).to eq(described_class.new(nil, "/location"))
    end

    it "with model.managed-in_field" do
      field = "Vm.managed-service_level"
      expect(described_class.parse(field)).to eq(described_class.new(Vm, "/managed/service_level"))
    end

    it "with model.last.managed-in_field" do
      field = "Vm.host.managed-environment"
      expect(described_class.parse(field)).to eq(described_class.new(Vm, "/host"))
    end
  end
end
