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

  describe "#column_type" do
    it "is always a string" do
      expect(described_class.new(Vm, "/host").column_type).to eq(:string)
    end
  end

  describe "#numeric?" do
    it "is never numeric" do
      expect(described_class.new(Vm, "/host")).not_to be_numeric
    end
  end

  describe "#sub_type" do
    it "is always a string" do
      expect(described_class.new(Vm, "/host").sub_type).to eq(:string)
    end
  end

  describe "#attribute_supported_by_sql?" do
    it "is always false" do
      expect(described_class.new(Vm, "/host")).not_to be_attribute_supported_by_sql
    end
  end

  describe "#tag?" do
    it { expect(described_class.new(Vm, "/host")).to be_tag }
  end

  describe "#field?" do
    it { expect(described_class.new(Vm, "/host")).not_to be_field }
  end
end
